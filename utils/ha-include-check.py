#!/usr/bin/env python3
"""
ha-include-check: Home Assistant Include Reference Checker

Purpose:
    Check include targets before configuration maintenance or deployment.

Behavior:
    - Scan the selected configuration file as text for !include,
      !include_dir_merge_list, and !include_dir_merge_named targets.
    - Check file/directory existence without recursively validating includes
      or parsing YAML. This does not replace Home Assistant's config check.
    - With -u, report files not explicitly referenced; subdirectories are
      ignored. If homeassistant points to an included file, customize* files
      whose basenames appear in its includes are excluded from that report.

Compatibility:
    Python 3 on Windows and Linux/Home Assistant shell environments.

Usage:
    From the repository root:
        python utils/ha-include-check.py [-c CONFIG_FILE] [-u DIR] [-q] [--json]
        python utils/ha-include-check.py --version
    In the Home Assistant runtime:
        python3 /config/utils/ha-include-check.py -c /config/configuration.yaml --json
    --help and --version exit without reading configuration files.

Inputs / environment:
    - -c / --config defaults to configuration.yaml in the working directory.
      Read configuration text as UTF-8; resolve include targets relative to
      the selected configuration file's directory.
    - -u / --unreferenced-files-dir selects an optional directory, also relative
      to the configuration file's directory unless an absolute path is supplied.
    - No script-specific environment variables or credentials are required.

Outputs / side effects:
    - Print text diagnostics, or JSON with timestamp, checks_completed, and
      results containing missing_files, missing_dirs, and optional unreferenced_files.
    - -q suppresses normal text output; --json takes precedence over -q.
      Read errors still print to stderr. No file writes or network calls.
    - Exit 0 for no findings, 1 for findings or configuration read errors,
      and 2 for invalid command-line arguments.

Prerequisites:
    Python 3.6+ standard library and read access to the selected files/directories.

Author:
    Torsten Juul-Jensen

Ownership / deployment:
    HomeAssistantConfig/utils/ha-include-check.py is the maintained source.
    Git-sync and deployment helpers invoke this read-only check. The runtime
    copy is /config/utils/ha-include-check.py, distributed with the config repo.
    See docs/runbooks/git-workflow.md for deployment and Core validation.

Version:
    1.0.0

Changelog:
    - 1.0.0: Establish version metadata and --version; document existing checks.
"""

import os
import re
import argparse
import sys
import json
from datetime import datetime

VERSION = "1.0.0"

# Default configuration file name
CONFIG_FILE = "configuration.yaml"

# Regex for matching !include and !include_dir_merge_* patterns
INCLUDE_REGEX = re.compile(r'!include(_dir_merge_(list|named))?\s+(.+)')


def load_config(file_path):
    """Read YAML file safely and return contents as text."""
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return f.read()
    except FileNotFoundError:
        sys.exit(f"Error: Could not find {file_path}")
    except Exception as e:
        sys.exit(f"Error: Failed to read {file_path} → {e}")


def find_includes(config_text):
    """
    Extract include directives from YAML.
    Returns a list of tuples: (mode, target).
    Example: ("_dir_merge_list", "automations/") or ("", "include/http.yaml")
    """
    includes = []
    for line in config_text.splitlines():
        match = INCLUDE_REGEX.search(line)
        if match:
            mode = match.group(1) or ""      # e.g. "_dir_merge_list" or ""
            target = match.group(3).strip()  # the referenced path
            includes.append((mode, target))
    return includes


def check_includes(base_path, includes):
    """
    Check that referenced includes exist.
    Returns:
        referenced_files: set of explicitly referenced files
        include_dirs: set of directories that contain referenced files
        missing_files: list of missing files
        missing_dirs: list of missing directories
    """
    referenced_files = set()
    include_dirs = set()
    missing_files = []
    missing_dirs = []

    for mode, target in includes:
        target_path = os.path.join(base_path, target)

        if "dir_merge" in mode:
            # Directory reference: check only directory exists
            if os.path.isdir(target_path):
                include_dirs.add(os.path.abspath(target_path))
            else:
                missing_dirs.append(os.path.abspath(target_path))
        else:
            # File reference: check file exists
            if os.path.isfile(target_path):
                referenced_files.add(os.path.abspath(target_path))
                include_dirs.add(os.path.abspath(os.path.dirname(target_path)))
            else:
                missing_files.append(os.path.abspath(target_path))

    return referenced_files, include_dirs, missing_files, missing_dirs


def check_unreferenced_files(directory, referenced_files):
    """
    Report unreferenced files in a specific directory (subdirs ignored).
    Returns list of unreferenced file paths.
    """
    unreferenced = []
    try:
        for entry in os.listdir(directory):
            full_path = os.path.join(directory, entry)
            if os.path.isfile(full_path):
                if os.path.abspath(full_path) not in referenced_files:
                    unreferenced.append(os.path.abspath(full_path))
    except FileNotFoundError:
        pass
    except PermissionError:
        pass
    return unreferenced


def find_homeassistant_include(config_text, base_path):
    """
    Look for 'homeassistant:' section pointing to a file via !include.
    Return absolute path if found and exists, otherwise None.
    """
    for line in config_text.splitlines():
        if line.strip().startswith("homeassistant:"):
            match = INCLUDE_REGEX.search(line)
            if match:
                target = match.group(3).strip()
                target_path = os.path.join(base_path, target)
                if os.path.isfile(target_path):
                    return os.path.abspath(target_path)
    return None


def filter_customize_unreferenced(unreferenced_files, homeassistant_file):
    """
    If a homeassistant include file exists, check if it references customize* files.
    Any customize* files found there are removed from unreferenced list.
    """
    if not homeassistant_file:
        return unreferenced_files

    try:
        text = load_config(homeassistant_file)
    except Exception:
        return unreferenced_files

    includes = find_includes(text)
    referenced = [os.path.basename(t[1]) for t in includes if t[1]]

    filtered = []
    for f in unreferenced_files:
        base = os.path.basename(f)
        if base.startswith("customize") and base in referenced:
            # Found in homeassistant.yaml → skip reporting
            continue
        filtered.append(f)

    return filtered


def main():
    parser = argparse.ArgumentParser(
        description="Check Home Assistant configuration.yaml for missing/unreferenced includes."
    )
    parser.add_argument(
        "-c", "--config",
        default=CONFIG_FILE,
        help=f"Path to configuration.yaml (default: {CONFIG_FILE})"
    )
    parser.add_argument(
        "-u", "--unreferenced-files-dir",
        help="Check for unreferenced files inside this directory (subdirs ignored)"
    )
    parser.add_argument(
        "-q", "--quiet",
        action="store_true",
        help="Quiet mode: no output, only exit status (0=clean, 1=issues)"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results in JSON format"
    )
    parser.add_argument("--version", action="version", version=VERSION)
    args = parser.parse_args()

    base_path = os.path.dirname(os.path.abspath(args.config)) or os.getcwd()
    config_text = load_config(args.config)

    # Step 1: find include references in configuration.yaml
    includes = find_includes(config_text)

    # Step 2: check for missing files/dirs
    referenced_files, _, missing_files, missing_dirs = check_includes(base_path, includes)

    # Step 3: optional check for unreferenced files
    unreferenced_files = None
    if args.unreferenced_files_dir:
        directory = os.path.abspath(os.path.join(base_path, args.unreferenced_files_dir))
        unreferenced_files = check_unreferenced_files(directory, referenced_files)

        # If unreferenced customize* files exist, check homeassistant.yaml
        homeassistant_file = find_homeassistant_include(config_text, base_path)
        if homeassistant_file and unreferenced_files:
            unreferenced_files = filter_customize_unreferenced(unreferenced_files, homeassistant_file)

    # Prepare results
    issues_found = bool(missing_files or missing_dirs or (unreferenced_files and len(unreferenced_files) > 0))
    checks_completed = not issues_found

    results = {
        "timestamp": datetime.now().astimezone().isoformat(),
        "checks_completed": checks_completed,
        "results": {
            "missing_files": missing_files,
            "missing_dirs": missing_dirs,
        }
    }
    if unreferenced_files is not None:
        results["results"]["unreferenced_files"] = unreferenced_files

    # JSON output mode
    if args.json:
        print(json.dumps(results, indent=2))
        sys.exit(1 if issues_found else 0)

    # Quiet mode
    if args.quiet:
        sys.exit(1 if issues_found else 0)

    # Human-readable output
    for d in missing_dirs:
        print(f"[MISSING DIR] {d}")
    for f in missing_files:
        print(f"[MISSING FILE] {f}")
    if unreferenced_files:
        for f in unreferenced_files:
            print(f"[UNREFERENCED FILE] {f}")

    if not issues_found:
        print("All checks passed. No issues found.")

    sys.exit(1 if issues_found else 0)


if __name__ == "__main__":
    main()
