#!/usr/bin/env python3
"""
Script Name:    garmin-livetrack-fetch.py
Description:    Fetch and normalize Garmin LiveTrack session data.

Purpose:
  Provide a Home Assistant command_line friendly fetch path for Garmin's current
  LiveTrack web app flow after the legacy GraphQL fields stopped working.

Behavior:
  - Accepts a LiveTrack URL or separate session/token values.
  - Fetches the public LiveTrack page first to collect cookies and CSRF data.
  - Calls the current /api/sessions/<session>?token=<token> route with the same
    cookies and Livetrack-Csrf-Token header when a CSRF token is available.
  - Extracts trackpoints from the API payload when present, otherwise searches
    server-rendered Next.js hydration data in the page HTML.
  - Emits Garmin's current trackpoint shape plus a legacy compatibility
    trackpoint for existing Home Assistant templates.
  - Writes atomically when --output is provided.
  - Returns structured errors instead of raw tracebacks.

Usage:
  python3 /config/utils/garmin-livetrack-fetch.py --url "<livetrack_url>"
  python3 /config/utils/garmin-livetrack-fetch.py --session "<id>" --token "<token>"
  python3 /config/utils/garmin-livetrack-fetch.py --url "<url>" --output /config/www/livetrack/live.json

Inputs / Environment:
  --url:
    Garmin LiveTrack URL. Supports /session/<id>/token/<token> and
    /session/<id>?token=<token> formats.
  --session / --token:
    Session and token values when the URL is not available.
  --timeout:
    HTTP timeout in seconds. Defaults to 20.
  --output:
    Optional JSON file destination.
  --debug:
    Include lightweight debug fields in the emitted JSON.

Outputs / Side Effects:
  - Prints normalized JSON to stdout.
  - Optionally writes the same JSON atomically to --output.
  - Performs HTTPS GET requests to livetrack.garmin.com.

Prerequisites:
  Python 3 standard library only.

Version:
  1.0.0

Changelog:
  1.0.0:
    - Added current Garmin LiveTrack page/API fetch flow.
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from http.cookiejar import CookieJar
from pathlib import Path
from typing import Any


LIVETRACK_HOST = "livetrack.garmin.com"
LIVETRACK_BASE = f"https://{LIVETRACK_HOST}"
USER_AGENT = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) HomeAssistantConfig/1.0 Safari/537.36"
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def empty_result() -> dict[str, Any]:
    return {
        "ok": False,
        "session": {},
        "trackPoints": [],
        "lastTrackPoint": {},
        "legacyLastTrackPoint": {},
        "trackpoint_count": 0,
        "errors": [],
        "fetched_at": utc_now(),
        "source": {},
    }


def add_error(result: dict[str, Any], code: str, message: str) -> None:
    result["errors"].append({"code": code, "message": message})
    result["ok"] = False


def parse_livetrack_identity(
    url: str | None,
    session: str | None,
    token: str | None,
) -> tuple[str | None, str | None, str | None]:
    clean_url = (url or "").strip().replace("=\r\n", "").replace("=\n", "")
    clean_url = re.sub(r"\r?\n", "", clean_url)

    parsed_session = (session or "").strip() or None
    parsed_token = (token or "").strip() or None

    if clean_url:
        parsed = urllib.parse.urlparse(clean_url)
        path_match = re.search(r"/session/([^/?#&]+)", parsed.path, re.IGNORECASE)
        token_match = re.search(r"/token/([^/?#&]+)", parsed.path, re.IGNORECASE)
        query = urllib.parse.parse_qs(parsed.query)

        if path_match and not parsed_session:
            parsed_session = urllib.parse.unquote(path_match.group(1))
        if token_match and not parsed_token:
            parsed_token = urllib.parse.unquote(token_match.group(1))
        if not parsed_session and query.get("session"):
            parsed_session = query["session"][0]
        if not parsed_token and query.get("token"):
            parsed_token = query["token"][0]

    if parsed_session and parsed_token:
        canonical_url = f"{LIVETRACK_BASE}/session/{parsed_session}/token/{parsed_token}"
    else:
        canonical_url = clean_url or None

    return parsed_session, parsed_token, canonical_url


def build_opener() -> urllib.request.OpenerDirector:
    cookie_jar = CookieJar()
    return urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookie_jar))


def request_text(
    opener: urllib.request.OpenerDirector,
    url: str,
    timeout: int,
    headers: dict[str, str] | None = None,
) -> tuple[str, int]:
    request_headers = {
        "User-Agent": USER_AGENT,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    }
    if headers:
        request_headers.update(headers)

    request = urllib.request.Request(url, headers=request_headers)
    with opener.open(request, timeout=timeout) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        body = response.read().decode(charset, errors="replace")
        return body, response.status


def request_json(
    opener: urllib.request.OpenerDirector,
    url: str,
    timeout: int,
    headers: dict[str, str] | None = None,
) -> tuple[Any, int]:
    body, status = request_text(
        opener,
        url,
        timeout,
        headers={
            "Accept": "application/json, text/plain, */*",
            **(headers or {}),
        },
    )
    return json.loads(body), status


def extract_csrf(page_html: str) -> str | None:
    patterns = [
        r'<meta[^>]+name=["\']csrf-token["\'][^>]+content=["\']([^"\']+)["\']',
        r'<meta[^>]+content=["\']([^"\']+)["\'][^>]+name=["\']csrf-token["\']',
        r'<meta[^>]+name=["\']csrfToken["\'][^>]+content=["\']([^"\']+)["\']',
    ]
    for pattern in patterns:
        match = re.search(pattern, page_html, flags=re.IGNORECASE)
        if match:
            return html.unescape(match.group(1))
    return None


def walk_values(value: Any) -> Any:
    yield value
    if isinstance(value, dict):
        for child in value.values():
            yield from walk_values(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_values(child)


def looks_like_trackpoint(value: Any) -> bool:
    return (
        isinstance(value, dict)
        and isinstance(value.get("dateTime"), str)
        and (
            isinstance(value.get("position"), dict)
            or isinstance(value.get("fitnessPointData"), dict)
        )
    )


def looks_like_trackpoint_list(value: Any) -> bool:
    return isinstance(value, list) and any(looks_like_trackpoint(item) for item in value)


def find_trackpoints(value: Any) -> list[dict[str, Any]]:
    candidates: list[list[dict[str, Any]]] = []
    for item in walk_values(value):
        if looks_like_trackpoint_list(item):
            points = [point for point in item if isinstance(point, dict)]
            candidates.append(points)
        elif isinstance(item, dict):
            for key in ("trackPoints", "trackpoints", "points"):
                nested = item.get(key)
                if looks_like_trackpoint_list(nested):
                    candidates.append([point for point in nested if isinstance(point, dict)])

    if not candidates:
        return []
    return max(candidates, key=len)


def looks_like_session(value: Any, session_id: str | None) -> bool:
    if not isinstance(value, dict):
        return False
    if session_id and value.get("sessionId") == session_id:
        return True
    return bool(value.get("sessionId") and (value.get("start") or value.get("userDisplayName")))


def find_session(value: Any, session_id: str | None) -> dict[str, Any]:
    for item in walk_values(value):
        if looks_like_session(item, session_id):
            return dict(item)
    return {}


def legacy_trackpoint(point: dict[str, Any]) -> dict[str, Any]:
    legacy = dict(point)
    if isinstance(legacy.get("fitnessPointData"), dict):
        return legacy

    fitness_keys = {
        "activityType",
        "cadenceCyclesPerMin",
        "distanceMeters",
        "durationSecs",
        "elevationGainMeters",
        "elevationSource",
        "eventTypes",
        "heartRateBeatsPerMin",
        "pointStatus",
        "powerWatts",
        "speedMetersPerSec",
        "totalDistanceMeters",
        "totalDurationSecs",
    }
    fitness_data = {key: legacy[key] for key in fitness_keys if key in legacy}
    if fitness_data:
        legacy["fitnessPointData"] = fitness_data

    if "speed" not in legacy and "speedMetersPerSec" in legacy:
        legacy["speed"] = legacy["speedMetersPerSec"]

    return legacy


def normalize_session(session: dict[str, Any]) -> dict[str, Any]:
    allowed_keys = {
        "end",
        "sessionId",
        "sessionName",
        "start",
        "userDisplayName",
        "viewable",
    }
    return {key: session[key] for key in allowed_keys if key in session}


def load_next_data(page_html: str) -> list[Any]:
    objects: list[Any] = []
    for match in re.finditer(
        r'<script[^>]+id=["\']__NEXT_DATA__["\'][^>]*>(.*?)</script>',
        page_html,
        flags=re.IGNORECASE | re.DOTALL,
    ):
        text = html.unescape(match.group(1)).strip()
        if not text:
            continue
        try:
            objects.append(json.loads(text))
        except json.JSONDecodeError:
            continue
    return objects


def extract_json_arrays_by_key(page_html: str, key: str) -> list[Any]:
    values: list[Any] = []
    marker = f'"{key}"'
    for marker_match in re.finditer(re.escape(marker), page_html):
        colon = page_html.find(":", marker_match.end())
        if colon == -1:
            continue
        start = page_html.find("[", colon)
        if start == -1:
            continue
        try:
            raw_array = balanced_json(page_html, start)
            values.append(json.loads(html.unescape(raw_array)))
        except (ValueError, json.JSONDecodeError):
            continue
    return values


def balanced_json(text: str, start: int) -> str:
    opening = text[start]
    closing = "]" if opening == "[" else "}"
    depth = 0
    in_string = False
    escape = False

    for index in range(start, len(text)):
        char = text[index]
        if in_string:
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == '"':
                in_string = False
            continue

        if char == '"':
            in_string = True
        elif char == opening:
            depth += 1
        elif char == closing:
            depth -= 1
            if depth == 0:
                return text[start : index + 1]

    raise ValueError("No balanced JSON value found")


def extract_hydration_data(page_html: str) -> list[Any]:
    objects = load_next_data(page_html)
    objects.extend(extract_json_arrays_by_key(page_html, "trackPoints"))

    # Next.js app router data may be embedded as escaped strings inside push()
    # calls. Decode likely string fragments and search them too.
    for match in re.finditer(r"self\.__next_f\.push\((.*?)\)</script>", page_html, re.DOTALL):
        chunk = html.unescape(match.group(1))
        for string_match in re.finditer(r'"((?:\\.|[^"\\])*)"', chunk):
            try:
                decoded = json.loads(f'"{string_match.group(1)}"')
            except json.JSONDecodeError:
                continue
            if "trackPoints" in decoded or "sessionId" in decoded:
                objects.extend(extract_json_arrays_by_key(decoded, "trackPoints"))
                try:
                    objects.append(json.loads(decoded))
                except json.JSONDecodeError:
                    pass
    return objects


def normalize_payload(
    session_payload: Any,
    page_html: str,
    session_id: str | None,
    debug: bool,
) -> dict[str, Any]:
    result = empty_result()
    result["source"] = {
        "session_id": session_id,
        "session_api": False,
        "trackpoints": "none",
    }

    session = find_session(session_payload, session_id)
    trackpoints = find_trackpoints(session_payload)
    if session_payload:
        result["source"]["session_api"] = True

    if not trackpoints:
        for hydration_object in extract_hydration_data(page_html):
            if not session:
                session = find_session(hydration_object, session_id)
            trackpoints = find_trackpoints(hydration_object)
            if trackpoints:
                result["source"]["trackpoints"] = "hydration"
                break
    else:
        result["source"]["trackpoints"] = "session_api"

    result["session"] = normalize_session(session) if session else {}
    result["trackPoints"] = trackpoints
    result["trackpoint_count"] = len(trackpoints)
    result["lastTrackPoint"] = trackpoints[-1] if trackpoints else {}
    result["legacyLastTrackPoint"] = legacy_trackpoint(trackpoints[-1]) if trackpoints else {}
    result["ok"] = bool(session)

    if not session:
        add_error(result, "missing_session", "No session object was found in Garmin response data")
    if not trackpoints:
        add_error(result, "missing_trackpoints", "No trackpoints were found in Garmin response data")

    if not debug:
        result["source"] = {k: v for k, v in result["source"].items() if k != "debug"}

    return result


def write_atomic(path_value: str, payload: dict[str, Any]) -> None:
    destination = Path(path_value).expanduser().resolve(strict=False)
    destination.parent.mkdir(parents=True, exist_ok=True)

    fd, temp_name = tempfile.mkstemp(prefix=f".{destination.name}.tmp.", dir=str(destination.parent))
    temp_path = Path(temp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, sort_keys=True)
            handle.write("\n")
        temp_path.replace(destination)
    finally:
        try:
            if temp_path.exists():
                temp_path.unlink()
        except OSError:
            pass


def fetch_livetrack(args: argparse.Namespace) -> dict[str, Any]:
    result = empty_result()
    session_id, token, canonical_url = parse_livetrack_identity(args.url, args.session, args.token)

    if not session_id:
        add_error(result, "missing_session_id", "LiveTrack session ID is missing")
    if not token:
        add_error(result, "missing_token", "LiveTrack token is missing")
    if result["errors"]:
        return result

    opener = build_opener()
    page_url = canonical_url or f"{LIVETRACK_BASE}/session/{session_id}/token/{token}"
    api_url = f"{LIVETRACK_BASE}/api/sessions/{urllib.parse.quote(session_id)}?token={urllib.parse.quote(token)}"

    try:
        page_html, page_status = request_text(opener, page_url, args.timeout)
    except urllib.error.HTTPError as exc:
        add_error(result, "page_http_error", f"LiveTrack page request failed: {exc.code} {exc.reason}")
        return result
    except urllib.error.URLError as exc:
        add_error(result, "page_url_error", f"LiveTrack page request failed: {exc.reason}")
        return result
    except OSError as exc:
        add_error(result, "page_request_error", f"LiveTrack page request failed: {exc}")
        return result

    csrf = extract_csrf(page_html)
    headers = {"Referer": page_url}
    if csrf:
        headers["Livetrack-Csrf-Token"] = csrf

    session_payload: Any = {}
    try:
        session_payload, api_status = request_json(opener, api_url, args.timeout, headers=headers)
    except urllib.error.HTTPError as exc:
        add_error(result, "session_http_error", f"LiveTrack session API request failed: {exc.code} {exc.reason}")
        api_status = exc.code
    except urllib.error.URLError as exc:
        add_error(result, "session_url_error", f"LiveTrack session API request failed: {exc.reason}")
        api_status = None
    except (OSError, json.JSONDecodeError) as exc:
        add_error(result, "session_request_error", f"LiveTrack session API request failed: {exc}")
        api_status = None

    normalized = normalize_payload(session_payload, page_html, session_id, args.debug)
    normalized["errors"] = result["errors"] + normalized["errors"]
    normalized["ok"] = normalized["ok"] and not any(
        error["code"] in {"page_http_error", "page_url_error", "page_request_error"}
        for error in normalized["errors"]
    )
    normalized["source"].update(
        {
            "session_id": session_id,
            "page_status": page_status,
            "api_status": api_status,
            "csrf_found": bool(csrf),
        }
    )
    return normalized


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fetch Garmin LiveTrack data as JSON")
    parser.add_argument("--url", default="", help="Garmin LiveTrack URL")
    parser.add_argument("--session", default="", help="Garmin LiveTrack session ID")
    parser.add_argument("--token", default="", help="Garmin LiveTrack token")
    parser.add_argument("--timeout", type=int, default=20, help="HTTP timeout in seconds")
    parser.add_argument("--output", default="", help="Optional output JSON file")
    parser.add_argument("--debug", action="store_true", help="Include lightweight debug data")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        payload = fetch_livetrack(args)
    except Exception as exc:  # noqa: BLE001 - Home Assistant needs JSON, not tracebacks.
        payload = empty_result()
        add_error(payload, "unexpected_error", str(exc))

    if args.output:
        try:
            write_atomic(args.output, payload)
        except OSError as exc:
            add_error(payload, "output_error", f"Could not write output file: {exc}")

    print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
