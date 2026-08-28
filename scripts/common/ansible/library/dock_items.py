#!/usr/bin/python

from __future__ import annotations

DOCUMENTATION = r"""
---
module: dock_items
short_description: Reconcile the current user's macOS Dock items
description:
  - Uses dockutil's documented tab-delimited list output as structured fields.
  - Reads native Dock plist fields for folder display, view, and sort options.
  - Rebuilds the Dock only when the ordered item definitions differ.
options:
  items:
    description: Ordered Dock item definitions.
    type: list
    elements: dict
    required: true
    suboptions:
      name:
        description: Human-readable item name used by the playbook.
        type: str
        required: false
      path:
        description: Application, directory, or URL to add.
        type: str
        required: true
      section:
        description: Dock section.
        choices: [apps, others]
        type: str
        default: apps
      options:
        description: Additional dockutil arguments for this item.
        type: list
        elements: str
        default: []
author:
  - dotfiles maintainers
attributes:
  check_mode:
    support: full
"""

EXAMPLES = r"""
- name: Configure Dock
  dock_items:
    items:
      - path: /Applications/Alacritty.app
      - path: /Users/me/Downloads
        section: others
        options: [--view, auto, --display, stack]
"""

RETURN = r"""
paths:
  description: Normalized paths found after reconciliation.
  returned: always
  type: list
  elements: str
"""

import plistlib
import subprocess
from pathlib import Path
from typing import Any
from urllib.parse import unquote, urlsplit

from ansible.module_utils.basic import AnsibleModule


def invoke(module: AnsibleModule, argv: list[str]) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(argv, capture_output=True, check=False, text=True)
    if result.returncode != 0:
        module.fail_json(
            msg="dockutil command failed",
            rc=result.returncode,
            stdout=result.stdout,
            stderr=result.stderr,
        )
    return result


DISPLAY_VALUES = {0: "stack", 1: "folder"}
VIEW_VALUES = {0: "auto", 1: "fan", 2: "grid", 3: "list"}
SORT_VALUES = {1: "name", 2: "dateadded", 3: "datemodified", 4: "datecreated", 5: "kind"}


def normalized_path(url: str) -> str:
    return unquote(urlsplit(url).path).rstrip("/")


def plist_folder_options(plist_path: str) -> dict[str, dict[str, str]]:
    with Path(plist_path).open("rb") as plist_file:
        plist = plistlib.load(plist_file)

    options = {}
    for tile in plist.get("persistent-others", []):
        tile_data = tile.get("tile-data", {})
        url = tile_data.get("file-data", {}).get("_CFURLString")
        if not url:
            continue
        path = normalized_path(url)
        options[path] = {
            "display": DISPLAY_VALUES.get(tile_data.get("displayas", 0), "unknown"),
            "view": VIEW_VALUES.get(tile_data.get("viewas", 0), "unknown"),
            "sort": SORT_VALUES.get(tile_data.get("arrangement", 1), "unknown"),
        }
    return options


def current_items(module: AnsibleModule, dockutil: str) -> list[dict[str, Any]]:
    output = invoke(module, [dockutil, "--list"]).stdout
    rows = []
    plist_paths = set()
    for line_number, line in enumerate(output.splitlines(), start=1):
        fields = line.split("\t")
        if len(fields) < 4:
            module.fail_json(msg=f"Unexpected dockutil output on line {line_number}: {line!r}")
        section = {"persistentApps": "apps", "persistentOthers": "others"}.get(fields[2])
        if section is None:
            module.fail_json(msg=f"Unexpected Dock section on line {line_number}: {fields[2]!r}")
        rows.append({"path": normalized_path(fields[1]), "section": section})
        plist_paths.add(fields[3])

    folder_options = {}
    for plist_path in plist_paths:
        folder_options.update(plist_folder_options(plist_path))
    for row in rows:
        row["options"] = folder_options.get(row["path"], {})
    return rows


def desired_items(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    desired = []
    for item in items:
        option_pairs = zip(item["options"][::2], item["options"][1::2], strict=True)
        options = {option.removeprefix("--"): value for option, value in option_pairs}
        desired.append(
            {"path": item["path"].rstrip("/"), "section": item["section"], "options": options}
        )
    return desired


def states_match(current: list[dict[str, Any]], desired: list[dict[str, Any]]) -> bool:
    if len(current) != len(desired):
        return False
    return all(
        actual["path"] == expected["path"]
        and actual["section"] == expected["section"]
        and all(actual["options"].get(key) == value for key, value in expected["options"].items())
        for actual, expected in zip(current, desired, strict=True)
    )


def main() -> None:
    module = AnsibleModule(
        argument_spec={
            "items": {
                "type": "list",
                "elements": "dict",
                "required": True,
                "options": {
                    "path": {"type": "str", "required": True},
                    "name": {"type": "str"},
                    "section": {"type": "str", "choices": ["apps", "others"], "default": "apps"},
                    "options": {"type": "list", "elements": "str", "default": []},
                },
            }
        },
        supports_check_mode=True,
    )
    dockutil = module.get_bin_path("dockutil", required=not module.check_mode)
    desired = desired_items(module.params["items"])
    if dockutil is None:
        module.exit_json(changed=True, paths=[], msg="dockutil is not installed yet")

    current = current_items(module, dockutil)
    if states_match(current, desired) or module.check_mode:
        module.exit_json(
            changed=not states_match(current, desired),
            paths=[item["path"] for item in current],
        )

    invoke(module, [dockutil, "--remove", "all", "--no-restart"])
    for item in module.params["items"]:
        argv = [dockutil, "--add", item["path"], "--position", "end", *item["options"]]
        if item["section"] != "apps":
            argv.extend(["--section", item["section"]])
        argv.append("--no-restart")
        invoke(module, argv)

    final = current_items(module, dockutil)
    if not states_match(final, desired):
        module.fail_json(
            msg="Dock still differs after reconciliation",
            changed=True,
            paths=[item["path"] for item in final],
        )
    module.exit_json(changed=True, paths=[item["path"] for item in final])


if __name__ == "__main__":
    main()
