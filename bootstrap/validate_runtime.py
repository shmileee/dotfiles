#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tomllib
from importlib.metadata import distributions
from pathlib import Path

import yaml

REPOSITORY_ROOT = Path(__file__).resolve().parent.parent


def fail(message: str) -> None:
    raise SystemExit(f"bootstrap runtime validation failed: {message}")


def command_output(*arguments: str) -> str:
    result = subprocess.run(
        arguments,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    if result.returncode != 0:
        fail(
            f"{' '.join(arguments)} exited with {result.returncode}: {result.stdout.strip()}"
        )
    return result.stdout.strip()


def normalized_name(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def configured_uv_version() -> str:
    setup_text = (REPOSITORY_ROOT / "bootstrap/setup.sh").read_text()
    match = re.search(r"^uv_version=([^\s#]+)$", setup_text, re.MULTILINE)
    if match is None:
        fail("bootstrap/setup.sh does not declare one uv_version")
    setup_version = match.group(1)

    with (REPOSITORY_ROOT / "mise.toml").open("rb") as mise_file:
        mise_version = tomllib.load(mise_file)["tools"]["uv"]

    integration_text = (
        REPOSITORY_ROOT / "tests/integration/Dockerfile"
    ).read_text()
    integration_match = re.search(
        r"^FROM ghcr\.io/astral-sh/uv:([^@\s]+)(?:@sha256:[0-9a-f]+)? AS uv$",
        integration_text,
        re.MULTILINE,
    )
    if integration_match is None:
        fail("tests/integration/Dockerfile does not declare one uv image")
    integration_version = integration_match.group(1)

    versions = {
        "bootstrap/setup.sh": setup_version,
        "mise.toml": mise_version,
        "tests/integration/Dockerfile": integration_version,
    }
    if len(set(versions.values())) != 1:
        fail(
            "uv version drift: "
            + ", ".join(
                f"{path} declares {version}"
                for path, version in versions.items()
            )
        )
    return setup_version


def validate_python_version() -> str:
    expected = (
        (REPOSITORY_ROOT / "bootstrap/.python-version").read_text().strip()
    )
    with (REPOSITORY_ROOT / "bootstrap/pyproject.toml").open(
        "rb"
    ) as project_file:
        required = tomllib.load(project_file)["project"]["requires-python"]
    if required != f"=={expected}":
        fail(
            "Python version drift: "
            f".python-version declares {expected}, pyproject.toml declares {required}"
        )

    actual = command_output(sys.executable, "--version").removeprefix("Python ")
    if actual != expected:
        fail(f"managed Python is {actual}, expected {expected}")
    return actual


def validate_python_packages() -> dict[str, str]:
    with (REPOSITORY_ROOT / "bootstrap/uv.lock").open("rb") as lock_file:
        lock = tomllib.load(lock_file)

    expected: dict[str, str] = {}
    for package in lock["package"]:
        if "registry" not in package["source"]:
            continue
        name = normalized_name(package["name"])
        if name in expected:
            fail(f"uv.lock contains multiple platform versions for {name}")
        expected[name] = package["version"]

    actual = {
        normalized_name(distribution.metadata["Name"]): distribution.version
        for distribution in distributions()
    }
    if actual != expected:
        missing = sorted(set(expected) - set(actual))
        extra = sorted(set(actual) - set(expected))
        changed = sorted(
            name
            for name in set(expected) & set(actual)
            if expected[name] != actual[name]
        )
        fail(
            "installed Python packages differ from uv.lock: "
            f"missing={missing}, extra={extra}, "
            f"changed={[(name, expected[name], actual[name]) for name in changed]}"
        )
    return actual


def expected_collections() -> dict[str, str]:
    requirements_path = REPOSITORY_ROOT / "bootstrap/ansible/requirements.yml"
    requirements = yaml.safe_load(requirements_path.read_text())
    expected = {
        item["name"]: str(item["version"])
        for item in requirements["collections"]
    }
    if len(expected) != len(requirements["collections"]):
        fail("Galaxy requirements contain duplicate collection names")
    if any(
        not version or any(character in version for character in "*<>=, ")
        for version in expected.values()
    ):
        fail("every Galaxy collection must have one exact version")
    return expected


def validate_collections(collections_path: Path) -> dict[str, str]:
    collection_root = collections_path / "ansible_collections"
    if not collection_root.is_dir():
        fail(f"collection root {collection_root} does not exist")

    actual: dict[str, str] = {}
    for namespace_path in sorted(collection_root.iterdir()):
        if not namespace_path.is_dir():
            continue
        for collection_path in sorted(namespace_path.iterdir()):
            if not collection_path.is_dir():
                continue
            manifest_path = collection_path / "MANIFEST.json"
            if not manifest_path.is_file():
                fail(f"collection path {collection_path} has no MANIFEST.json")
            metadata = json.loads(manifest_path.read_text())["collection_info"]
            name = f"{metadata['namespace']}.{metadata['name']}"
            expected_path = (
                collection_root / metadata["namespace"] / metadata["name"]
            )
            if collection_path != expected_path:
                fail(
                    f"collection {name} is installed at unexpected path {collection_path}"
                )
            if name in actual:
                fail(f"collection {name} is installed more than once")
            actual[name] = str(metadata["version"])

    expected = expected_collections()
    if actual != expected:
        fail(
            f"installed collections {actual} differ from requirements {expected}"
        )
    return actual


def checkout_commit(checkout: Path) -> str | None:
    git = shutil.which("git")
    if git is None or not checkout.exists():
        return None
    result = subprocess.run(
        [git, "-C", str(checkout), "rev-parse", "HEAD"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--uv-executable", default="uv")
    parser.add_argument(
        "--collections-path",
        type=Path,
        default=REPOSITORY_ROOT / "bootstrap/.ansible/collections",
    )
    parser.add_argument("--checkout", type=Path, default=REPOSITORY_ROOT)
    return parser.parse_args()


def main() -> None:
    arguments = parse_arguments()
    expected_uv = configured_uv_version()
    uv_report = command_output(arguments.uv_executable, "--version")
    actual_uv = uv_report.split()[1] if len(uv_report.split()) >= 2 else ""
    if actual_uv != expected_uv:
        fail(f"active uv is {actual_uv or uv_report}, expected {expected_uv}")

    python_version = validate_python_version()
    packages = validate_python_packages()
    collections = validate_collections(arguments.collections_path)
    ansible_report = command_output(
        "ansible-playbook", "--version"
    ).splitlines()[0]
    commit = checkout_commit(arguments.checkout)

    print(
        f"persistent checkout commit: {commit or 'not available before playbook'}"
    )
    print(f"uv: {uv_report}")
    print(f"Python: {python_version}")
    print(f"Ansible: {ansible_report}")
    print("locked Python packages:")
    for name, version in sorted(packages.items()):
        print(f"  {name}=={version}")
    print("pinned Ansible collections:")
    for name, version in sorted(collections.items()):
        print(f"  {name}=={version}")


if __name__ == "__main__":
    main()
