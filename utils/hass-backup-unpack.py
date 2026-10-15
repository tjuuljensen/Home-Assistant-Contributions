#!/usr/bin/env python3
"""
utils/hass-backup-unpack.py

Purpose:
  Inspect and unpack Home Assistant backup tar files, including nested encrypted
  `.tar.gz` payloads used by Home Assistant backups.

Author:
  Torsten Juul-Jensen

Behavior:
  - Lists first-level backup members by default.
  - Unpacks selected nested `.tar.gz` members, or all nested archives, into a
    folder derived from the backup path.
  - Prompts for the backup decryption key only when extraction is requested.
  - Removes extracted nested `.tar.gz` files after successful unpack so the
    output folder contains the unpacked content rather than the encrypted blobs.
  - Uses path-safe extraction for both top-level and nested tar members.

Usage:
  python utils/hass-backup-unpack.py path/to/backup.tar
  python utils/hass-backup-unpack.py path/to/backup.tar --extract all
  python utils/hass-backup-unpack.py path/to/backup.tar --extract ssl.tar.gz
  python utils/hass-backup-unpack.py path/to/backup.tar --extract all --output-dir path/to/output
  python utils/hass-backup-unpack.py path/to/backup.tar --verbose

Version:
  1.1.0

Changelog:
  - 1.1.0: Added richer built-in help output and deferred `securetar`
    dependency loading so listing and help work without extraction support.
  - 1.0.0: Initial cleaned repo version with argparse, safer extraction, and
    clearer operator output.

Inputs / environment:
  - Required CLI arg: backup TAR path
  - Optional CLI arg: --extract {all|<member.tar.gz>}
  - Optional CLI arg: --output-dir
  - Optional CLI flag: --verbose
  - Interactive prompt for backup decryption key when --extract is used

Outputs / side effects:
  - Prints backup member names or extraction progress to stdout.
  - Creates or replaces output directories under the chosen output path.
  - Deletes extracted nested `.tar.gz` files from the output directory after
    successful unpack.

Prerequisites:
  - Python 3.10+
  - `securetar` installed in the active Python environment when using
    `--extract`
"""

from __future__ import annotations

import argparse
import getpass
import hashlib
import re
import shutil
import sys
import tarfile
from pathlib import Path
from textwrap import dedent
from typing import NoReturn

SCRIPT_VERSION = "1.1.0"
RE_GZFILE = re.compile(r"^(.+)\.tar\.gz$")
RE_TARFILE = re.compile(r"^(.+)\.tar$")


def fatal(message: str, exit_code: int = 1) -> NoReturn:
    print(message, file=sys.stderr)
    raise SystemExit(exit_code)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Inspect or unpack Home Assistant backup tar files.",
        epilog=dedent(
            """\
            Examples:
              python utils/hass-backup-unpack.py /path/to/backup.tar
              python utils/hass-backup-unpack.py /path/to/backup.tar --extract all
              python utils/hass-backup-unpack.py /path/to/backup.tar --extract ssl.tar.gz
              python utils/hass-backup-unpack.py /path/to/backup.tar --extract homeassistant.tar.gz --verbose
            """
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "backup_tar",
        help="Path to the Home Assistant backup .tar file.",
    )
    parser.add_argument(
        "--extract",
        metavar="TARGET",
        help='Extract "all" nested archives or a specific member such as "ssl.tar.gz".',
    )
    parser.add_argument(
        "--output-dir",
        help="Optional base output directory. Default: sibling folder derived from the backup filename.",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Show additional extraction detail.",
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {SCRIPT_VERSION}",
    )
    return parser.parse_args()


def load_securetar():
    try:
        import securetar  # type: ignore
    except ImportError:
        fatal(
            'Missing dependency: "securetar"\n'
            "Extraction requires securetar because Home Assistant nested backup payloads may be encrypted.\n"
            "Install it with:\n"
            "  pip install securetar"
        )
    return securetar


def password_to_key(password: str) -> bytes:
    key = password.encode()
    for _ in range(100):
        key = hashlib.sha256(key).digest()
    return key[:16]


def ensure_backup_tar(path: Path) -> None:
    if not path.exists():
        fatal(f"Backup file does not exist: {path}")
    if not path.is_file():
        fatal(f"Backup path is not a file: {path}")
    if not RE_TARFILE.search(path.name):
        fatal(f"Expected a .tar backup file, got: {path.name}")


def get_output_root(backup_tar: Path, output_dir: str | None) -> Path:
    if output_dir:
        return Path(output_dir).expanduser().resolve()
    match = RE_TARFILE.search(backup_tar.name)
    if not match:
        fatal(f"Expected a .tar backup file, got: {backup_tar.name}")
    return (backup_tar.parent / match.group(1)).resolve()


def list_backup_files(tar_path: Path) -> list[str]:
    try:
        with tarfile.open(tar_path, "r") as tar:
            return [member.name for member in tar.getmembers() if member.isfile()]
    except tarfile.TarError as exc:
        fatal(f"Unable to read backup tar {tar_path}: {exc}")


def ensure_safe_member_path(base_dir: Path, member_name: str) -> Path:
    target = (base_dir / member_name).resolve()
    try:
        target.relative_to(base_dir.resolve())
    except ValueError:
        fatal(f"Unsafe archive member path blocked: {member_name}")
    return target


def extract_safe_tar_members(archive: tarfile.TarFile, destination: Path, verbose: bool) -> None:
    for member in archive.getmembers():
        target = ensure_safe_member_path(destination, member.name)

        if member.isdir():
            target.mkdir(parents=True, exist_ok=True)
            continue

        if not member.isfile():
            fatal(f"Unsupported nested archive member type blocked: {member.name}")

        target.parent.mkdir(parents=True, exist_ok=True)
        source = archive.extractfile(member)
        if source is None:
            fatal(f'Unable to open nested archive member: "{member.name}"')

        if verbose:
            print(f"  file: {member.name}")

        with source, target.open("wb") as handle:
            shutil.copyfileobj(source, handle)


def extract_member_from_tar(tar_path: Path, member_name: str, output_root: Path, verbose: bool) -> Path:
    with tarfile.open(tar_path, "r") as tar:
        try:
            member = tar.getmember(member_name)
        except KeyError:
            fatal(f'Backup does not contain member: "{member_name}"')

        if not member.isfile():
            fatal(f'Backup member is not a regular file: "{member_name}"')

        destination = ensure_safe_member_path(output_root, member.name)
        destination.parent.mkdir(parents=True, exist_ok=True)

        if verbose:
            print(f"Extracting top-level member: {member.name}")

        source = tar.extractfile(member)
        if source is None:
            fatal(f'Unable to open backup member: "{member.name}"')

        with source, destination.open("wb") as handle:
            shutil.copyfileobj(source, handle)

        return destination


def unpack_encrypted_tgz(tar_gz_path: Path, destination: Path, password: str, verbose: bool) -> None:
    securetar = load_securetar()
    print(f"Unpacking nested archive: {tar_gz_path.name}")
    shutil.rmtree(destination, ignore_errors=True)
    destination.mkdir(parents=True, exist_ok=True)

    try:
        with securetar.SecureTarFile(
            str(tar_gz_path),
            gzip=True,
            key=password_to_key(password) if password else None,
            mode="r",
        ) as archive:
            if verbose:
                print(f"  destination: {destination}")
            extract_safe_tar_members(archive, destination, verbose)
    except tarfile.ReadError:
        fatal("Bad nested archive content or incorrect decryption key.")


def nested_target_names(files: list[str], target: str) -> list[str]:
    if target == "all":
        names = [name for name in files if RE_GZFILE.search(name)]
        if not names:
            fatal("No nested .tar.gz members found in the backup.")
        return names

    if not RE_GZFILE.search(target):
        fatal('Expected --extract target to be "all" or a specific .tar.gz member name.')

    return [target]


def print_listing(files: list[str]) -> None:
    for file_name in files:
        print(file_name)
    print('\nAdd --extract all or --extract <member.tar.gz> to unpack nested content.')


def extract_targets(
    backup_tar: Path,
    output_root: Path,
    target_names: list[str],
    verbose: bool,
) -> None:
    password = getpass.getpass("Enter backup decryption key (leave empty for unencrypted): ")

    for member_name in target_names:
        match = RE_GZFILE.search(member_name)
        if not match:
            fatal(f"Unexpected nested archive name: {member_name}")

        subfolder = output_root / match.group(1)
        extracted_tar_gz = extract_member_from_tar(backup_tar, member_name, output_root, verbose)
        unpack_encrypted_tgz(extracted_tar_gz, subfolder, password, verbose)
        extracted_tar_gz.unlink()

        if verbose:
            print(f"Removed extracted encrypted blob: {extracted_tar_gz}")


def main() -> int:
    args = parse_args()
    backup_tar = Path(args.backup_tar).expanduser().resolve()
    ensure_backup_tar(backup_tar)

    files = list_backup_files(backup_tar)
    if not args.extract:
        print_listing(files)
        return 0

    output_root = get_output_root(backup_tar, args.output_dir)
    output_root.mkdir(parents=True, exist_ok=True)
    targets = nested_target_names(files, args.extract)
    extract_targets(backup_tar, output_root, targets, args.verbose)
    print(f"Done. Output root: {output_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
