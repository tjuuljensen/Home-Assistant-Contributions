#!/usr/bin/env python3
"""
Name:
    export-button-card-templates.py

Purpose:
    Export custom:button-card templates from Home Assistant Lovelace config.

Behavior:
    - Scans YAML files and selected Lovelace `.storage` JSON files below a Home Assistant config root.
    - Extracts `button_card_templates` mappings.
    - Skips generated button-card export snapshots under `/config/docs/exports/button-card`.
    - Can write all templates to one YAML file.
    - Can write dependency-connected template groups to separate YAML files.
    - Defaults output to `/config/docs/exports/button-card/current` under the selected config root.
    - Refuses to overwrite existing output files unless `--overwrite` is used.

Usage:
    python3 /config/utils/export-button-card-templates.py --config-root /config --output-dir /config/docs/exports/button-card/current --all-in-one
    python3 /config/utils/export-button-card-templates.py --config-root /config --output-dir /config/docs/exports/button-card/current --interconnected

Inputs:
    --config-root:
        Home Assistant config directory to scan. Defaults to the current directory.
    --output-dir:
        Directory where exported YAML files are written. Defaults to
        `<config-root>/docs/exports/button-card/current`.
    --all-in-one:
        Export every discovered template to one `button_card_templates.yaml` file.
    --interconnected:
        Export connected template dependency groups to separate files.
    --overwrite:
        Replace existing output files instead of failing.

Outputs and side effects:
    - Writes YAML export files under `--output-dir`.
    - Prints export summary details to stdout.
    - Returns a non-zero exit code when output files already exist and `--overwrite` is not set.

Prerequisites:
    - Python 3.
    - PyYAML.
    - Read access to the Home Assistant config tree.
    - Write access to the selected output directory.

Author:
    Torsten Juul-Jensen

Version:
    1.0.0

Changelog:
    1.0.0 - Initial versioned public utility; add --version to the existing exporter.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict, deque
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml


SCRIPT_VERSION = "1.0.0"


SKIP_DIRS = {
    ".cache",
    ".cloud",
    ".git",
    ".ssh",
    "custom_components",
    "deps",
    "tts",
    "www",
}


class HomeAssistantLoader(yaml.SafeLoader):
    """YAML loader that tolerates Home Assistant's custom tags."""


@dataclass
class DuplicateRecord:
    """Track repeated template definitions without emitting one warning per collision."""

    name: str
    occurrences: list[str] = field(default_factory=list)


@dataclass
class TemplateMapMatch:
    """One discovered button-card template mapping and its in-file location."""

    location: str
    templates: dict[str, Any]


def _unknown_tag(loader: HomeAssistantLoader, tag_suffix: str, node: yaml.Node) -> Any:
    if isinstance(node, yaml.ScalarNode):
        return loader.construct_scalar(node)
    if isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node)
    if isinstance(node, yaml.MappingNode):
        return loader.construct_mapping(node)
    return None


HomeAssistantLoader.add_multi_constructor("!", _unknown_tag)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Export button_card_templates from Lovelace YAML and .storage config."
    )
    parser.add_argument(
        "--version", action="version", version=f"%(prog)s {SCRIPT_VERSION}"
    )
    parser.add_argument(
        "--config-root",
        default=".",
        help="Home Assistant config directory to scan. Default: current directory.",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        default=None,
        help="Directory to write exported YAML files. Default: <config-root>/docs/exports/button-card/current.",
    )

    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--all-in-one",
        action="store_true",
        help="Export every template to one button_card_templates.yaml file.",
    )
    mode.add_argument(
        "--interconnected",
        action="store_true",
        help="Export connected template dependency groups to separate files.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing export files instead of failing.",
    )
    return parser.parse_args()


def yaml_files(config_root: Path) -> list[Path]:
    files: list[Path] = []
    for path in config_root.rglob("*"):
        if any(part in SKIP_DIRS for part in path.relative_to(config_root).parts):
            continue
        if path.is_file() and path.suffix.lower() in {".yaml", ".yml"}:
            files.append(path)
    return sorted(files)


def storage_files(config_root: Path) -> list[Path]:
    storage = config_root / ".storage"
    if not storage.exists():
        return []
    return sorted(
        path
        for path in storage.iterdir()
        if path.is_file() and (path.name.startswith("lovelace") or "dashboard" in path.name)
    )


def load_yaml(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as file:
        return yaml.load(file, Loader=HomeAssistantLoader)


def load_storage_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def format_node_path(parts: list[str]) -> str:
    path = ""
    for part in parts:
        if part.startswith("["):
            path += part
        elif path:
            path += f".{part}"
        else:
            path = part
    return path or "<root>"


def find_template_maps(node: Any, path_parts: list[str] | None = None) -> list[TemplateMapMatch]:
    if path_parts is None:
        path_parts = []
    matches: list[TemplateMapMatch] = []
    if isinstance(node, dict):
        templates = node.get("button_card_templates")
        if isinstance(templates, dict):
            matches.append(
                TemplateMapMatch(
                    location=format_node_path(path_parts + ["button_card_templates"]),
                    templates=templates,
                )
            )
        for key, value in node.items():
            matches.extend(find_template_maps(value, path_parts + [str(key)]))
    elif isinstance(node, list):
        for index, item in enumerate(node):
            matches.extend(find_template_maps(item, path_parts + [f"[{index}]"]))
    return matches


def is_relative_to(path: Path, other: Path) -> bool:
    try:
        path.relative_to(other)
        return True
    except ValueError:
        return False


def should_skip_yaml_file(path: Path, config_root: Path, output_dir: Path) -> bool:
    relative_parts = path.relative_to(config_root).parts
    if any(part in SKIP_DIRS for part in relative_parts):
        return True
    if is_relative_to(path, output_dir):
        return True
    exports_root = config_root / "docs" / "exports" / "button-card"
    if is_relative_to(path, exports_root):
        return True
    return False


def collect_templates(
    config_root: Path, output_dir: Path
) -> tuple[dict[str, Any], dict[str, list[str]], list[str], list[DuplicateRecord]]:
    templates: dict[str, Any] = {}
    sources: dict[str, list[str]] = defaultdict(list)
    warnings: list[str] = []
    duplicates: dict[str, DuplicateRecord] = {}

    for path in yaml_files(config_root):
        if should_skip_yaml_file(path, config_root, output_dir):
            continue
        try:
            data = load_yaml(path)
        except Exception as exc:  # noqa: BLE001 - report and continue through user config.
            warnings.append(f"Skipped YAML {path}: {exc}")
            continue
        for match in find_template_maps(data):
            add_templates(templates, sources, match.templates, path, match.location, duplicates)

    for path in storage_files(config_root):
        try:
            data = load_storage_json(path)
        except Exception as exc:  # noqa: BLE001 - report and continue through user config.
            warnings.append(f"Skipped storage {path}: {exc}")
            continue
        for match in find_template_maps(data):
            add_templates(templates, sources, match.templates, path, match.location, duplicates)

    return templates, sources, warnings, sorted(duplicates.values(), key=lambda item: item.name)


def add_templates(
    templates: dict[str, Any],
    sources: dict[str, list[str]],
    template_map: dict[str, Any],
    path: Path,
    location: str,
    duplicates: dict[str, DuplicateRecord],
) -> None:
    source_label = f"{path}::{location}"
    for name, value in template_map.items():
        if not isinstance(name, str):
            continue
        if name in templates:
            record = duplicates.setdefault(name, DuplicateRecord(name=name))
            if not record.occurrences:
                record.occurrences.append(sources[name][0])
            record.occurrences.append(source_label)
        templates[name] = value
        sources[name].append(source_label)


def referenced_templates(node: Any, known_names: set[str]) -> set[str]:
    refs: set[str] = set()
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "template":
                refs.update(template_names_from_value(value, known_names))
            refs.update(referenced_templates(value, known_names))
    elif isinstance(node, list):
        for item in node:
            refs.update(referenced_templates(item, known_names))
    return refs


def template_names_from_value(value: Any, known_names: set[str]) -> set[str]:
    if isinstance(value, str):
        return {value} if value in known_names else set()
    if isinstance(value, list):
        return {item for item in value if isinstance(item, str) and item in known_names}
    return set()


def connected_groups(templates: dict[str, Any]) -> list[list[str]]:
    known_names = set(templates)
    graph: dict[str, set[str]] = {name: set() for name in templates}

    for name, value in templates.items():
        for ref in referenced_templates(value, known_names):
            if ref == name:
                continue
            graph[name].add(ref)
            graph[ref].add(name)

    groups: list[list[str]] = []
    seen: set[str] = set()
    for start in sorted(templates):
        if start in seen:
            continue
        group: list[str] = []
        queue: deque[str] = deque([start])
        seen.add(start)
        while queue:
            name = queue.popleft()
            group.append(name)
            for neighbor in sorted(graph[name]):
                if neighbor not in seen:
                    seen.add(neighbor)
                    queue.append(neighbor)
        groups.append(sorted(group))
    return groups


def write_yaml(path: Path, template_names: list[str], templates: dict[str, Any], overwrite: bool) -> None:
    if path.exists() and not overwrite:
        raise FileExistsError(f"{path} already exists. Use --overwrite to replace it.")
    payload = {"button_card_templates": {name: templates[name] for name in template_names}}
    with path.open("w", encoding="utf-8", newline="\n") as file:
        yaml.safe_dump(payload, file, sort_keys=False, allow_unicode=True, width=120)


def safe_filename(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9_.-]+", "_", value).strip("._")
    return value or "templates"


def export_all(templates: dict[str, Any], output_dir: Path, overwrite: bool) -> list[Path]:
    path = output_dir / "button_card_templates.yaml"
    write_yaml(path, sorted(templates), templates, overwrite)
    return [path]


def export_groups(templates: dict[str, Any], output_dir: Path, overwrite: bool) -> list[Path]:
    written: list[Path] = []
    for index, group in enumerate(connected_groups(templates), start=1):
        if len(group) == 1:
            label = safe_filename(group[0])
        else:
            label = safe_filename("__".join(group[:3]))
            if len(group) > 3:
                label = f"{label}__plus_{len(group) - 3}"
        path = output_dir / f"button_card_templates_group_{index:02d}_{label}.yaml"
        write_yaml(path, group, templates, overwrite)
        written.append(path)
    return written


def summarize_duplicates(duplicates: list[DuplicateRecord]) -> list[str]:
    if not duplicates:
        return []

    by_path: dict[str, set[str]] = defaultdict(set)
    same_file_duplicates: list[str] = []
    cross_file_duplicates: list[str] = []

    for record in duplicates:
        unique_paths = list(dict.fromkeys(record.occurrences))
        for path in unique_paths:
            by_path[path].add(record.name)
        if len(unique_paths) == 1:
            same_file_duplicates.append(
                f"{record.name} ({len(record.occurrences)} definitions in {unique_paths[0]})"
            )
        else:
            cross_file_duplicates.append(f"{record.name} ({' -> '.join(unique_paths)})")

    lines = [
        "Duplicate template summary:",
        "  Later definitions win. This is separate from --overwrite, which only replaces output files.",
        f"  {len(duplicates)} template name(s) were defined more than once.",
        f"  {len(by_path)} file(s) participated in duplicate definitions.",
    ]

    for path in sorted(by_path):
        names = sorted(by_path[path])
        preview = ", ".join(names[:8])
        suffix = f" (+{len(names) - 8} more)" if len(names) > 8 else ""
        lines.append(f"  - {path}: {len(names)} template(s) [{preview}{suffix}]")

    if same_file_duplicates:
        preview = ", ".join(sorted(same_file_duplicates)[:8])
        suffix = f" (+{len(same_file_duplicates) - 8} more)" if len(same_file_duplicates) > 8 else ""
        lines.append(f"  Repeated within the same file: {preview}{suffix}")

    if cross_file_duplicates:
        preview = "; ".join(sorted(cross_file_duplicates)[:6])
        suffix = f" (+{len(cross_file_duplicates) - 6} more)" if len(cross_file_duplicates) > 6 else ""
        lines.append(f"  Cross-file overrides: {preview}{suffix}")

    return lines


def main() -> int:
    args = parse_args()
    config_root = Path(args.config_root).expanduser().resolve()
    output_dir = (
        Path(args.output_dir).expanduser().resolve()
        if args.output_dir
        else (config_root / "docs" / "exports" / "button-card" / "current").resolve()
    )
    output_dir.mkdir(parents=True, exist_ok=True)

    templates, sources, warnings, duplicates = collect_templates(config_root, output_dir)
    if not templates:
        print(f"No button_card_templates found under {config_root}", file=sys.stderr)
        return 1

    try:
        if args.interconnected:
            written = export_groups(templates, output_dir, args.overwrite)
        else:
            written = export_all(templates, output_dir, args.overwrite)
    except FileExistsError as exc:
        print(exc, file=sys.stderr)
        return 2

    print(f"Found {len(templates)} button-card templates from {len(set(sum(sources.values(), [])))} source files.")
    for path in written:
        print(f"Wrote {path}")
    for line in summarize_duplicates(duplicates):
        print(line, file=sys.stderr)
    for warning in warnings:
        print(f"Warning: {warning}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
