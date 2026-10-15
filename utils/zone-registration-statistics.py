#!/usr/bin/env python3
"""Read zone-registration CSV statistics for Home Assistant.

Purpose:
    Provide the monthly and yearly JSON consumed by
    sensor.zone_registration_statistics without shell parsing.

Behavior:
    Preserve the former jq row counting and sorted grouping. Skip the header
    and final newline-split item, including an unterminated final record.
    Unreadable files return empty arrays quietly, with a successful exit.

Compatibility:
    Python 3.9+ standard library on Windows and Home Assistant.

Usage / inputs:
    python3 /config/utils/zone-registration-statistics.py --file PATH
    --file is the selected registration CSV. No environment variables are used.
    --help and --version do not read files.

Outputs / side effects:
    Print one JSON object to stdout. Only read the CSV; no file writes or
    network calls. Count rows without validating dates or deduplicating them.

Prerequisites:
    Python and read access to the selected CSV.

Ownership:
    Maintained with the source configuration; public copies are publication outputs.

Version:
    1.0.0

Changelog:
    1.0.0: Replace the zone statistics jq command and shell error fallback.
"""

import argparse
from collections import Counter
import json
from pathlib import Path


VERSION = "1.0.0"


def statistics(path: Path) -> dict[str, list[dict[str, object]]]:
    """Return the existing jq grouping contract from a read-only CSV."""
    try:
        # Keep LF splitting and jq's replacement of invalid UTF-8 bytes.
        content = path.read_bytes().decode("utf-8", errors="replace")
    except OSError:
        return {"monthly": [], "yearly": []}

    months: Counter[str] = Counter()
    years: Counter[str] = Counter()
    for row in content.split("\n")[1:-1]:
        date = row.split(";", 1)[0]
        months[date[:7]] += 1
        years[date[:4]] += 1

    return {
        "monthly": [
            {
                "month": month,
                "date": month + "-01",
                "days": months[month],
                "year": month[:4],
            }
            for month in sorted(months)
        ],
        "yearly": [
            {"year": year, "days": years[year]}
            for year in sorted(years)
        ],
    }


def main() -> int:
    """Emit statistics or the existing quiet read-error fallback."""
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--file", type=Path, required=True, help="Registration CSV to read")
    parser.add_argument("--version", action="version", version=VERSION)
    args = parser.parse_args()
    print(json.dumps(statistics(args.file), separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
