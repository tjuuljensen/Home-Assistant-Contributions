#!/usr/bin/env python3
"""
Purpose:
    Find Home Assistant sensor and binary_sensor definitions that appear unused.

Behavior:
    - Scans legacy and modern YAML definitions and common !include targets.
    - Matches static references in configuration, templates, scripts, and
      automations; --include-storage also scans Lovelace/dashboard storage.
    - Reports unused, possibly unused, excluded, unresolved, and parse-error
      findings as text or JSON without modifying the configuration.

Usage:
    python utils/find-unused-sensors.py --config-root /config
    python utils/find-unused-sensors.py --config-root /config --json
    python utils/find-unused-sensors.py --config-root /config --fail-on unused
    python utils/find-unused-sensors.py --version

Inputs / options:
    --config-root PATH, --entity-types LIST, --exclude-file PATH,
    --exclude-glob GLOB, --include-storage, --format {text,json},
    --fail-on {unused,possibly_unused,never}, --quiet, and --verbose.
    Use --help for the complete option reference.

Outputs / side effects:
    Prints a read-only report and returns 0, 1 for requested findings, or 2
    for invalid input, parse errors, or analysis failures.

Limitations:
    Dynamically generated entity IDs and Jinja expressions are not evaluated.
    UI-managed entities are out of scope unless present in scanned storage.

Author:
    Torsten Juul-Jensen

Based on:
    https://github.com/basnijholt/home-assistant-config/blob/main/utils/find-unused-sensors.py

Version:
    1.0.0

Changelog:
    1.0.0 - Initial versioned repository adaptation.

Prerequisites:
    Python 3.10+, PyYAML, and read access to the scanned configuration path.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import sys
import unicodedata
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable

import yaml


__version__ = "1.0.0"

VALID_ENTITY_TYPES = ("sensor", "binary_sensor")
YAML_SUFFIXES = {".yaml", ".yml"}
DEFAULT_SKIP_DIRS = {
    ".cache",
    ".cloud",
    ".git",
    ".ssh",
    ".storage",
    "__pycache__",
    "custom_components",
    "deps",
    "docs",
    "glances",
    "image",
    "themes",
    "tts",
    "www",
}
STORAGE_REFERENCE_PATTERNS = ("lovelace*", "*dashboard*")
KNOWN_JINJA_HELPERS = ("states", "is_state", "state_attr", "expand")
STRUCTURED_KEYS = {"entity", "entity_id", "entity_ids", "entities", "source"}
ENTITY_TOKEN_RE = re.compile(r"\b(?:sensor|binary_sensor)\.[a-z0-9_]+\b")
INCLUDE_LINE_RE = re.compile(
    r"^\s*([A-Za-z0-9_ ]+):\s*!include(_dir_merge_(list|named))?\s+(.+?)\s*$"
)


class LineDict(dict):
    """dict with YAML line metadata."""

    _line: int | None
    _end_line: int | None
    _key_lines: dict[Any, tuple[int | None, int | None]]


class LineList(list):
    """list with YAML line metadata."""

    _line: int | None
    _end_line: int | None
    _item_lines: list[tuple[int | None, int | None]]


class HomeAssistantLoader(yaml.SafeLoader):
    """YAML loader that tolerates Home Assistant-specific tags."""


def _construct_unknown_tag(loader: HomeAssistantLoader, tag_suffix: str, node: yaml.Node) -> Any:
    if isinstance(node, yaml.ScalarNode):
        return loader.construct_scalar(node)
    if isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node)
    if isinstance(node, yaml.MappingNode):
        return loader.construct_mapping(node)
    return None


def _construct_mapping(loader: HomeAssistantLoader, node: yaml.MappingNode, deep: bool = False) -> LineDict:
    loader.flatten_mapping(node)
    mapping = LineDict()
    mapping._line = node.start_mark.line + 1
    mapping._end_line = node.end_mark.line + 1
    mapping._key_lines = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        value = loader.construct_object(value_node, deep=deep)
        mapping[key] = value
        mapping._key_lines[key] = (value_node.start_mark.line + 1, value_node.end_mark.line + 1)
    return mapping


def _construct_sequence(loader: HomeAssistantLoader, node: yaml.SequenceNode, deep: bool = False) -> LineList:
    sequence = LineList()
    sequence._line = node.start_mark.line + 1
    sequence._end_line = node.end_mark.line + 1
    sequence._item_lines = []
    for child in node.value:
        sequence.append(loader.construct_object(child, deep=deep))
        sequence._item_lines.append((child.start_mark.line + 1, child.end_mark.line + 1))
    return sequence


HomeAssistantLoader.add_multi_constructor("!", _construct_unknown_tag)
HomeAssistantLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
    _construct_mapping,
)
HomeAssistantLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_SEQUENCE_TAG,
    _construct_sequence,
)


@dataclass(frozen=True)
class EntityDefinition:
    entity_id: str
    kind: str
    defined_in: str
    line: int | None
    end_line: int | None
    reason: str


@dataclass(frozen=True)
class UnresolvedDefinition:
    kind: str
    defined_in: str
    line: int | None
    reason: str


@dataclass(frozen=True)
class ParseErrorRecord:
    file: str
    error: str


@dataclass(frozen=True)
class UsageFinding:
    entity_id: str
    kind: str
    defined_in: str
    line: int | None
    reason: str
    strong_references: int
    weak_references: int


@dataclass(frozen=True)
class ExcludedEntity:
    entity_id: str
    kind: str
    defined_in: str
    line: int | None
    reason: str


@dataclass(frozen=True)
class AnalysisResult:
    timestamp: str
    config_root: str
    checks_completed: bool
    summary: dict[str, int]
    results: dict[str, Any]


@dataclass(frozen=True)
class IncludeRegistry:
    files: dict[str, set[str]]
    directories: dict[str, set[str]]


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Find likely unused Home Assistant sensors and binary sensors."
    )
    parser.add_argument(
        "--config-root",
        default=".",
        help="Home Assistant config directory to scan. Default: current directory.",
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Shortcut for --format json.",
    )
    parser.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        help="Output format. Default: text.",
    )
    parser.add_argument(
        "--include-storage",
        action="store_true",
        help="Scan .storage Lovelace/dashboard files for references.",
    )
    parser.add_argument(
        "--entity-types",
        default="sensor,binary_sensor",
        help="Comma-separated entity domains to analyze. Default: sensor,binary_sensor.",
    )
    parser.add_argument(
        "--exclude-file",
        help="Text file containing entity-id or glob patterns to ignore, one per line.",
    )
    parser.add_argument(
        "--exclude-glob",
        action="append",
        default=[],
        help="Glob for files to skip while scanning. Repeatable.",
    )
    parser.add_argument(
        "--fail-on",
        choices=("unused", "possibly_unused", "never"),
        default="never",
        help="Exit non-zero when findings match the selected severity. Default: never.",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress text output. JSON output is still printed.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Include unresolved definitions, exclusions, and parse errors in text output.",
    )
    return parser.parse_args(argv)


def parse_entity_types(raw: str) -> set[str]:
    entity_types = {item.strip() for item in raw.split(",") if item.strip()}
    invalid = sorted(entity_types - set(VALID_ENTITY_TYPES))
    if invalid:
        joined = ", ".join(invalid)
        raise ValueError(f"Unsupported entity type(s): {joined}")
    return entity_types or set(VALID_ENTITY_TYPES)


def slugify_name(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    ascii_value = normalized.encode("ascii", "ignore").decode("ascii")
    slug = re.sub(r"[^a-zA-Z0-9_]+", "_", ascii_value).strip("_").lower()
    return re.sub(r"_+", "_", slug)


def normalize_entity_id(kind: str, value: str | None) -> str | None:
    if not value:
        return None
    candidate = value.strip().lower()
    if not candidate:
        return None
    if "." in candidate:
        domain, object_id = candidate.split(".", 1)
        if domain != kind or not re.fullmatch(r"[a-z0-9_]+", object_id):
            return None
        return f"{domain}.{object_id}"
    object_id = slugify_name(candidate)
    if not object_id:
        return None
    return f"{kind}.{object_id}"


def is_static_string(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    return "{{" not in value and "{%" not in value and "{#" not in value


def get_line_range(container: Any, key: Any | None = None) -> tuple[int | None, int | None]:
    if key is not None and isinstance(container, LineDict):
        return container._key_lines.get(key, (None, None))
    return getattr(container, "_line", None), getattr(container, "_end_line", None)


def load_yaml_text(text: str) -> Any:
    return yaml.load(text, Loader=HomeAssistantLoader)


def read_text_file(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def path_matches_globs(path: Path, config_root: Path, patterns: Iterable[str]) -> bool:
    rel_path = path.relative_to(config_root).as_posix()
    for pattern in patterns:
        if fnmatch.fnmatch(rel_path, pattern) or fnmatch.fnmatch(path.name, pattern):
            return True
    return False


def should_skip_dir(dir_name: str, include_storage: bool) -> bool:
    if dir_name == ".storage":
        return not include_storage
    return dir_name in DEFAULT_SKIP_DIRS


def collect_yaml_files(config_root: Path, exclude_globs: Iterable[str]) -> list[Path]:
    files: list[Path] = []
    for root, dirs, filenames in os.walk(config_root):
        dirs[:] = [
            name
            for name in dirs
            if not should_skip_dir(name, include_storage=False)
        ]
        root_path = Path(root)
        for filename in filenames:
            path = root_path / filename
            if path.suffix.lower() not in YAML_SUFFIXES:
                continue
            if path_matches_globs(path, config_root, exclude_globs):
                continue
            files.append(path)
    return sorted(files)


def collect_reference_files(
    config_root: Path,
    include_storage: bool,
    exclude_globs: Iterable[str],
) -> list[Path]:
    files = collect_yaml_files(config_root, exclude_globs)
    if not include_storage:
        return files

    storage_dir = config_root / ".storage"
    if not storage_dir.exists():
        return files

    for entry in sorted(storage_dir.iterdir()):
        if not entry.is_file():
            continue
        if not any(fnmatch.fnmatch(entry.name, pattern) for pattern in STORAGE_REFERENCE_PATTERNS):
            continue
        if path_matches_globs(entry, config_root, exclude_globs):
            continue
        files.append(entry)
    return files


def build_include_registry(config_root: Path) -> IncludeRegistry:
    config_path = config_root / "configuration.yaml"
    if not config_path.exists():
        return IncludeRegistry(files={}, directories={})

    files: dict[str, set[str]] = {}
    directories: dict[str, set[str]] = {}
    try:
        text = read_text_file(config_path)
    except OSError:
        return IncludeRegistry(files={}, directories={})

    for line in text.splitlines():
        match = INCLUDE_LINE_RE.match(line)
        if not match:
            continue
        key = match.group(1).strip()
        include_mode = match.group(2) or ""
        target = match.group(4).strip()
        target = target.strip("'\"")
        if key not in VALID_ENTITY_TYPES and key != "template":
            continue
        resolved = (config_root / target).resolve()
        if "dir_merge" in include_mode:
            directories.setdefault(str(resolved), set()).add(key)
        else:
            files.setdefault(str(resolved), set()).add(key)
    return IncludeRegistry(files=files, directories=directories)


def resolve_explicit_entity_id(kind: str, config: dict[str, Any]) -> str | None:
    default_entity_id = normalize_entity_id(kind, config.get("default_entity_id"))
    if default_entity_id:
        return default_entity_id
    object_id = normalize_entity_id(kind, config.get("object_id"))
    if object_id:
        return object_id
    return None


def definition_from_named_mapping(
    kind: str,
    object_id: str,
    config: Any,
    path: Path,
    reason: str,
    line_range: tuple[int | None, int | None] | None = None,
) -> EntityDefinition:
    entity_id = normalize_entity_id(kind, object_id)
    if entity_id is None:
        raise ValueError(f"Could not normalize object id '{object_id}'")
    if line_range is None:
        line_range = get_line_range(config)
    line, end_line = line_range
    if isinstance(config, (LineDict, LineList)):
        line = line or getattr(config, "_line", None)
        end_line = end_line or getattr(config, "_end_line", None)
    return EntityDefinition(
        entity_id=entity_id,
        kind=kind,
        defined_in=str(path),
        line=line,
        end_line=end_line,
        reason=reason,
    )


def definition_from_config(
    kind: str,
    config: dict[str, Any],
    path: Path,
    reason: str,
) -> EntityDefinition | UnresolvedDefinition:
    explicit = resolve_explicit_entity_id(kind, config)
    line = getattr(config, "_line", None)
    end_line = getattr(config, "_end_line", None)
    if explicit:
        return EntityDefinition(
            entity_id=explicit,
            kind=kind,
            defined_in=str(path),
            line=line,
            end_line=end_line,
            reason=reason,
        )

    name = config.get("name")
    if is_static_string(name):
        entity_id = normalize_entity_id(kind, name)
        if entity_id:
            return EntityDefinition(
                entity_id=entity_id,
                kind=kind,
                defined_in=str(path),
                line=line,
                end_line=end_line,
                reason=reason,
            )

    return UnresolvedDefinition(
        kind=kind,
        defined_in=str(path),
        line=line,
        reason="missing_static_entity_id_or_name",
    )


def extract_legacy_domain_list(
    domain: str,
    entries: Any,
    path: Path,
) -> tuple[list[EntityDefinition], list[UnresolvedDefinition]]:
    definitions: list[EntityDefinition] = []
    unresolved: list[UnresolvedDefinition] = []
    if not isinstance(entries, list):
        return definitions, unresolved

    for entry in entries:
        if not isinstance(entry, dict):
            continue
        if str(entry.get("platform", "")).lower() == "template":
            sensor_map = entry.get("sensors")
            if not isinstance(sensor_map, dict):
                unresolved.append(
                    UnresolvedDefinition(
                        kind=domain,
                        defined_in=str(path),
                        line=getattr(entry, "_line", None),
                        reason="legacy_template_without_sensors_mapping",
                    )
                )
                continue
            for object_id, config in sensor_map.items():
                line_range = get_line_range(sensor_map, object_id)
                definitions.append(
                    definition_from_named_mapping(
                        domain,
                        str(object_id),
                        config,
                        path,
                        reason="legacy_template",
                        line_range=line_range,
                    )
                )
            continue

        result = definition_from_config(domain, entry, path, reason="legacy_platform")
        if isinstance(result, EntityDefinition):
            definitions.append(result)
        else:
            unresolved.append(result)
    return definitions, unresolved


def extract_modern_template_blocks(
    blocks: Any,
    path: Path,
    entity_types: set[str],
) -> tuple[list[EntityDefinition], list[UnresolvedDefinition]]:
    definitions: list[EntityDefinition] = []
    unresolved: list[UnresolvedDefinition] = []
    if not isinstance(blocks, list):
        return definitions, unresolved

    for block in blocks:
        if not isinstance(block, dict):
            continue
        for kind in entity_types:
            entities = block.get(kind)
            if not isinstance(entities, list):
                continue
            for entity in entities:
                if not isinstance(entity, dict):
                    continue
                result = definition_from_config(kind, entity, path, reason="modern_template")
                if isinstance(result, EntityDefinition):
                    definitions.append(result)
                else:
                    unresolved.append(result)
    return definitions, unresolved


def discover_entity_definitions(
    data: Any,
    path: Path,
    entity_types: set[str],
    include_contexts: Iterable[str] | None = None,
) -> tuple[list[EntityDefinition], list[UnresolvedDefinition]]:
    definitions: list[EntityDefinition] = []
    unresolved: list[UnresolvedDefinition] = []
    contexts = set(include_contexts or [])

    if isinstance(data, dict):
        for kind in entity_types:
            if kind in data:
                found, unresolved_found = extract_legacy_domain_list(kind, data[kind], path)
                definitions.extend(found)
                unresolved.extend(unresolved_found)

        if "template" in data:
            found, unresolved_found = extract_modern_template_blocks(data["template"], path, entity_types)
            definitions.extend(found)
            unresolved.extend(unresolved_found)

    if isinstance(data, list):
        if "template" in contexts:
            found, unresolved_found = extract_modern_template_blocks(data, path, entity_types)
            definitions.extend(found)
            unresolved.extend(unresolved_found)
        for kind in entity_types:
            if kind in contexts:
                found, unresolved_found = extract_legacy_domain_list(kind, data, path)
                definitions.extend(found)
                unresolved.extend(unresolved_found)

    return dedupe_definitions(definitions), unresolved


def dedupe_definitions(definitions: list[EntityDefinition]) -> list[EntityDefinition]:
    seen: set[tuple[str, str, int | None]] = set()
    unique: list[EntityDefinition] = []
    for definition in definitions:
        key = (definition.entity_id, definition.defined_in, definition.line)
        if key in seen:
            continue
        seen.add(key)
        unique.append(definition)
    return unique


def classify_line_reference(entity_id: str, line: str) -> str | None:
    escaped = re.escape(entity_id)
    jinja_patterns = [
        rf"\bstates\s*\(\s*['\"]{escaped}['\"]\s*\)",
        rf"\bis_state\s*\(\s*['\"]{escaped}['\"]\s*,",
        rf"\bstate_attr\s*\(\s*['\"]{escaped}['\"]\s*,",
        rf"\bexpand\s*\(\s*['\"]{escaped}['\"]",
    ]
    if any(re.search(pattern, line) for pattern in jinja_patterns):
        return "strong"

    structured_patterns = [
        rf"\b(?:entity_id|entity|source)\b\s*:\s*['\"]?{escaped}['\"]?",
        rf"^\s*-\s*['\"]?{escaped}['\"]?\s*(?:#.*)?$",
        rf"\bentity_ids\b\s*:\s*\[[^\]]*{escaped}[^\]]*\]",
        rf"\bentities\b\s*:\s*\[[^\]]*{escaped}[^\]]*\]",
    ]
    if any(re.search(pattern, line) for pattern in structured_patterns):
        return "strong"

    if re.search(rf"(?<![A-Za-z0-9_]){escaped}(?![A-Za-z0-9_])", line):
        return "weak"

    return None


def build_reference_index(reference_files: list[Path]) -> dict[str, list[tuple[str, int, str]]]:
    index: dict[str, list[tuple[str, int, str]]] = {}
    for path in reference_files:
        try:
            text = read_text_file(path)
        except OSError:
            continue
        for line_no, line in enumerate(text.splitlines(), start=1):
            candidates = set(ENTITY_TOKEN_RE.findall(line))
            if not candidates:
                continue
            for entity_id in candidates:
                classification = classify_line_reference(entity_id, line)
                if classification is None:
                    continue
                index.setdefault(entity_id, []).append((str(path.resolve()), line_no, classification))
    return index


def scan_references_for_definition(
    definition: EntityDefinition,
    reference_index: dict[str, list[tuple[str, int, str]]],
) -> tuple[int, int]:
    strong = 0
    weak = 0
    definition_path = str(Path(definition.defined_in).resolve())
    for path, line_no, classification in reference_index.get(definition.entity_id, []):
        if (
            path == definition_path
            and definition.line is not None
            and definition.end_line is not None
            and definition.line <= line_no <= definition.end_line
        ):
            continue
        if classification == "strong":
            strong += 1
        elif classification == "weak":
            weak += 1
    return strong, weak


def load_exclusion_patterns(path: Path | None) -> list[str]:
    if path is None or not path.exists():
        return []
    patterns: list[str] = []
    for raw_line in read_text_file(path).splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        patterns.append(line)
    return patterns


def entity_matches_exclusions(entity_id: str, patterns: Iterable[str]) -> bool:
    return any(fnmatch.fnmatch(entity_id, pattern) for pattern in patterns)


def analyze_config(
    config_root: Path,
    *,
    entity_types: set[str],
    include_storage: bool,
    exclude_globs: list[str],
    exclusion_patterns: list[str],
) -> AnalysisResult:
    include_registry = build_include_registry(config_root)
    yaml_files = collect_yaml_files(config_root, exclude_globs)
    reference_files = collect_reference_files(config_root, include_storage, exclude_globs)

    definitions: list[EntityDefinition] = []
    unresolved: list[UnresolvedDefinition] = []
    parse_errors: list[ParseErrorRecord] = []

    for path in yaml_files:
        try:
            data = load_yaml_text(read_text_file(path))
        except (OSError, yaml.YAMLError) as exc:
            parse_errors.append(ParseErrorRecord(file=str(path), error=str(exc)))
            continue

        contexts = set(include_registry.files.get(str(path.resolve()), set()))
        resolved_path = str(path.resolve())
        for directory, mapped_contexts in include_registry.directories.items():
            try:
                path.relative_to(Path(directory))
            except ValueError:
                continue
            contexts.update(mapped_contexts)

        found, unresolved_found = discover_entity_definitions(
            data,
            path.resolve(),
            entity_types,
            include_contexts=contexts,
        )
        definitions.extend(found)
        unresolved.extend(unresolved_found)

    definitions = dedupe_definitions(definitions)

    excluded: list[ExcludedEntity] = []
    active_definitions: list[EntityDefinition] = []
    for definition in definitions:
        if entity_matches_exclusions(definition.entity_id, exclusion_patterns):
            excluded.append(
                ExcludedEntity(
                    entity_id=definition.entity_id,
                    kind=definition.kind,
                    defined_in=definition.defined_in,
                    line=definition.line,
                    reason="matched_exclusion_pattern",
                )
            )
        else:
            active_definitions.append(definition)

    unused: list[UsageFinding] = []
    possibly_unused: list[UsageFinding] = []
    reference_index = build_reference_index(reference_files)
    for definition in active_definitions:
        strong_refs, weak_refs = scan_references_for_definition(definition, reference_index)
        if strong_refs == 0 and weak_refs == 0:
            unused.append(
                UsageFinding(
                    entity_id=definition.entity_id,
                    kind=definition.kind,
                    defined_in=definition.defined_in,
                    line=definition.line,
                    reason="no_references_found",
                    strong_references=strong_refs,
                    weak_references=weak_refs,
                )
            )
        elif strong_refs == 0 and weak_refs > 0:
            possibly_unused.append(
                UsageFinding(
                    entity_id=definition.entity_id,
                    kind=definition.kind,
                    defined_in=definition.defined_in,
                    line=definition.line,
                    reason="only_weak_references_found",
                    strong_references=strong_refs,
                    weak_references=weak_refs,
                )
            )

    summary = {
        "entities_scanned": len(definitions),
        "unused": len(unused),
        "possibly_unused": len(possibly_unused),
        "excluded": len(excluded),
        "parse_errors": len(parse_errors),
        "unresolved_definitions": len(unresolved),
    }

    return AnalysisResult(
        timestamp=datetime.now().astimezone().isoformat(),
        config_root=str(config_root),
        checks_completed=not parse_errors,
        summary=summary,
        results={
            "unused": [asdict(item) for item in unused],
            "possibly_unused": [asdict(item) for item in possibly_unused],
            "excluded": [asdict(item) for item in excluded],
            "parse_errors": [asdict(item) for item in parse_errors],
            "unresolved_definitions": [asdict(item) for item in unresolved],
        },
    )


def render_text(result: AnalysisResult, verbose: bool) -> str:
    lines = [
        (
            "Summary: "
            f"entities_scanned={result.summary['entities_scanned']}, "
            f"unused={result.summary['unused']}, "
            f"possibly_unused={result.summary['possibly_unused']}, "
            f"excluded={result.summary['excluded']}, "
            f"parse_errors={result.summary['parse_errors']}, "
            f"unresolved_definitions={result.summary['unresolved_definitions']}"
        )
    ]

    for category in ("unused", "possibly_unused"):
        label = category.upper()
        for item in result.results[category]:
            location = f"{item['defined_in']}:{item['line'] or '?'}"
            lines.append(
                f"{label} {item['entity_id']} ({item['kind']}) at {location} [{item['reason']}]"
            )

    if verbose:
        for item in result.results["excluded"]:
            location = f"{item['defined_in']}:{item['line'] or '?'}"
            lines.append(f"EXCLUDED {item['entity_id']} ({item['kind']}) at {location} [{item['reason']}]")
        for item in result.results["unresolved_definitions"]:
            location = f"{item['defined_in']}:{item['line'] or '?'}"
            lines.append(f"UNRESOLVED {item['kind']} at {location} [{item['reason']}]")
        for item in result.results["parse_errors"]:
            lines.append(f"PARSE_ERROR {item['file']} [{item['error']}]")

    return "\n".join(lines)


def render_json(result: AnalysisResult) -> str:
    payload = {
        "timestamp": result.timestamp,
        "config_root": result.config_root,
        "checks_completed": result.checks_completed,
        "summary": result.summary,
        "results": result.results,
    }
    return json.dumps(payload, indent=2, sort_keys=False)


def determine_exit_code(result: AnalysisResult, fail_on: str) -> int:
    if result.summary["parse_errors"] > 0:
        return 2
    if fail_on == "never":
        return 0
    if fail_on == "unused" and result.summary["unused"] > 0:
        return 1
    if fail_on == "possibly_unused" and (
        result.summary["unused"] > 0 or result.summary["possibly_unused"] > 0
    ):
        return 1
    return 0


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        entity_types = parse_entity_types(args.entity_types)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2

    config_root = Path(args.config_root).expanduser().resolve()
    if not config_root.exists() or not config_root.is_dir():
        print(f"Error: config root '{config_root}' is not a directory.", file=sys.stderr)
        return 2

    exclusion_patterns = load_exclusion_patterns(
        Path(args.exclude_file).expanduser().resolve() if args.exclude_file else None
    )
    output_format = "json" if args.json else args.format

    try:
        result = analyze_config(
            config_root,
            entity_types=entity_types,
            include_storage=args.include_storage,
            exclude_globs=args.exclude_glob,
            exclusion_patterns=exclusion_patterns,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"Error: {exc}", file=sys.stderr)
        return 2

    if output_format == "json":
        print(render_json(result))
    elif not args.quiet:
        print(render_text(result, verbose=args.verbose))

    return determine_exit_code(result, args.fail_on)


if __name__ == "__main__":
    raise SystemExit(main())
