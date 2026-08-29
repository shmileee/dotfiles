#!/usr/bin/env python3
"""Add content hashes to local stylesheet and script URLs in a built site."""

from __future__ import annotations

import argparse
import hashlib
import html
import re
from pathlib import Path
from urllib.parse import unquote, unquote_plus, urlsplit, urlunsplit

TAG_PATTERN = re.compile(r"<(?:link|script)\b[^>]*>", re.IGNORECASE)
TAG_NAME_PATTERN = re.compile(r"<(?P<name>link|script)\b", re.IGNORECASE)
ATTRIBUTE_PATTERN = re.compile(
    r"(?P<name>[^\s=/>]+)(?P<separator>\s*=\s*)"
    r"(?P<quote>['\"])(?P<value>.*?)(?P=quote)",
    re.DOTALL,
)


def content_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12]


def attributes(tag: str) -> dict[str, str]:
    return {
        match.group("name").lower(): html.unescape(match.group("value"))
        for match in ATTRIBUTE_PATTERN.finditer(tag)
    }


def replace_attribute(tag: str, name: str, value: str) -> str:
    escaped = html.escape(value, quote=True)

    def replace(match: re.Match[str]) -> str:
        if match.group("name").lower() != name:
            return match.group(0)
        return (
            f"{match.group('name')}{match.group('separator')}"
            f"{match.group('quote')}{escaped}{match.group('quote')}"
        )

    return ATTRIBUTE_PATTERN.sub(replace, tag)


def asset_path(url: str, html_path: Path, site_dir: Path) -> Path | None:
    parsed = urlsplit(url)
    if parsed.scheme or parsed.netloc or not parsed.path:
        return None

    decoded_path = unquote(parsed.path)
    if decoded_path.startswith("/"):
        candidate = site_dir / decoded_path.lstrip("/")
    else:
        candidate = html_path.parent / decoded_path

    site_root = site_dir.resolve()
    candidate = candidate.resolve()
    if not candidate.is_relative_to(site_root):
        raise RuntimeError(f"Asset URL escapes the site directory: {url}")
    if not candidate.is_file():
        raise FileNotFoundError(f"Referenced asset does not exist: {candidate}")
    return candidate


def versioned_url(url: str, version: str) -> str:
    parsed = urlsplit(url)
    parameters = [
        parameter
        for parameter in parsed.query.split("&")
        if parameter
        and unquote_plus(parameter.partition("=")[0]).lower() != "v"
    ]
    parameters.append(f"v={version}")
    return urlunsplit(parsed._replace(query="&".join(parameters)))


def version_tag(
    tag: str,
    html_path: Path,
    site_dir: Path,
    versions: dict[Path, str],
) -> str:
    tag_name_match = TAG_NAME_PATTERN.match(tag)
    if tag_name_match is None:
        return tag

    tag_name = tag_name_match.group("name").lower()
    tag_attributes = attributes(tag)
    if tag_name == "link":
        relations = tag_attributes.get("rel", "").lower().split()
        if "stylesheet" not in relations:
            return tag
        url_attribute = "href"
    else:
        url_attribute = "src"

    url = tag_attributes.get(url_attribute)
    if not url:
        return tag

    path = asset_path(url, html_path, site_dir)
    if path is None:
        return tag

    version = versions.get(path)
    if version is None:
        version = versions[path] = content_hash(path)
    return replace_attribute(tag, url_attribute, versioned_url(url, version))


def version_assets(site_dir: Path) -> dict[Path, str]:
    versions: dict[Path, str] = {}

    for html_path in site_dir.rglob("*.html"):
        source = html_path.read_text(encoding="utf-8")
        updated = TAG_PATTERN.sub(
            lambda match, html_path=html_path: version_tag(
                match.group(0),
                html_path,
                site_dir,
                versions,
            ),
            source,
        )
        if updated != source:
            html_path.write_text(updated, encoding="utf-8")

    if not versions:
        raise RuntimeError(
            f"No local stylesheets or scripts found in {site_dir}"
        )
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
    site_root = args.site_dir.resolve()
    for asset, version in sorted(versions.items()):
        print(
            f"Versioned {asset.relative_to(site_root).as_posix()} as {version}"
        )


if __name__ == "__main__":
    main()
