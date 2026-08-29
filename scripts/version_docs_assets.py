#!/usr/bin/env python3
"""Add content hashes to custom documentation asset URLs."""

from __future__ import annotations

import argparse
import hashlib
import re
from pathlib import Path

ASSETS = (
    Path("assets/stylesheets/mkdocs.css"),
    Path("assets/javascripts/site-shell.js"),
)


def content_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12]


def version_assets(site_dir: Path) -> dict[Path, str]:
    versions = {asset: content_hash(site_dir / asset) for asset in ASSETS}
    replacements = dict.fromkeys(ASSETS, 0)

    for html_path in site_dir.rglob("*.html"):
        source = html_path.read_text(encoding="utf-8")
        updated = source

        for asset, version in versions.items():
            reference = asset.as_posix()
            pattern = rf"{re.escape(reference)}(?:\?v=[^\"']+)?(?=[\"'])"
            updated, count = re.subn(
                pattern,
                f"{reference}?v={version}",
                updated,
            )
            replacements[asset] += count

        if updated != source:
            html_path.write_text(updated, encoding="utf-8")

    missing = [asset for asset, count in replacements.items() if count == 0]
    if missing:
        names = ", ".join(asset.as_posix() for asset in missing)
        raise RuntimeError(f"No HTML references found for: {names}")

    return versions


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "site_dir",
        nargs="?",
        type=Path,
        default=Path("site"),
        help="Built documentation directory (default: site)",
    )
    args = parser.parse_args()

    versions = version_assets(args.site_dir)
    for asset, version in versions.items():
        print(f"Versioned {asset.as_posix()} as {version}")


if __name__ == "__main__":
    main()
