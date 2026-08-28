#!/usr/bin/python

from __future__ import annotations

DOCUMENTATION = r"""
---
module: dock_items
short_description: Reconcile the current user's macOS Dock
description:
  - Reconciles the exact ordered set of persistent Dock items.
  - Parses dockutil's tab-delimited output and reads native plist fields for folder presentation.
  - Validates every requested item before changing the Dock and attempts rollback after a failed rebuild.
requirements:
  - dockutil
options:
  items:
    description: Exact ordered Dock item definitions.
    type: list
    elements: dict
    required: true
    suboptions:
      name:
        description: Optional human-readable label returned in diagnostics.
        type: str
      path:
        description: Absolute file path, home-relative path, file URL, or network URL.
        type: str
        required: true
      section:
        description: Dock section in which to place the item.
        choices: [apps, others]
        type: str
        default: apps
      display:
        description: Folder representation. Valid only for filesystem items in V(others).
        choices: [stack, folder]
        type: str
      view:
        description: Folder content view. Valid only for filesystem items in V(others).
        choices: [auto, fan, grid, list]
        type: str
      sort:
        description: Folder sort order. Valid only for filesystem items in V(others).
        choices: [name, dateadded, datemodified, datecreated, kind]
        type: str
author:
  - dotfiles maintainers
attributes:
  check_mode:
    support: full
  diff_mode:
    support: full
platform:
  - macos
"""

EXAMPLES = r"""
- name: Configure the Dock
  dock_items:
    items:
      - name: Terminal
        path: /Applications/Alacritty.app
      - name: Downloads
        path: ~/Downloads
        section: others
        view: auto
        display: stack
        sort: dateadded
"""

RETURN = r"""
items:
  description: Normalized Dock items after reconciliation, or current items in check mode.
  returned: always
  type: list
  elements: dict
paths:
  description: Normalized paths after reconciliation, or current paths in check mode.
  returned: always
  type: list
  elements: str
rollback:
  description: Whether restoration of the previous Dock succeeded after a mutation failure.
  returned: on failure after mutation
  type: bool
"""

import plistlib
from pathlib import Path
from typing import Any, Dict, List, Mapping, Optional, Tuple
from urllib.parse import urlsplit

from ansible.module_utils.basic import AnsibleModule
from ansible.module_utils.dotfiles_macos import (
    dock_option_arguments,
    dock_states_match,
    normalize_location,
    parse_dockutil_output,
)


DISPLAY_VALUES = {0: "stack", 1: "folder"}
VIEW_VALUES = {0: "auto", 1: "fan", 2: "grid", 3: "list"}
SORT_VALUES = {1: "name", 2: "dateadded", 3: "datemodified", 4: "datecreated", 5: "kind"}


class DockError(Exception):
    pass


class DockCommandError(DockError):
    def __init__(self, argv: List[str], rc: int, stdout: str, stderr: str) -> None:
        super().__init__("dockutil command failed")
        self.argv = argv
        self.rc = rc
        self.stdout = stdout
        self.stderr = stderr


class DockStateError(DockError):
    pass


def run_dockutil(module: AnsibleModule, argv: List[str]) -> str:
    rc, stdout, stderr = module.run_command(argv)
    if rc != 0:
        raise DockCommandError(argv, rc, stdout, stderr)
    return stdout


def folder_options(plist_paths: List[str]) -> Dict[str, Dict[str, str]]:
    options = {}
    for plist_path in sorted(set(plist_paths)):
        try:
            with Path(plist_path).open("rb") as plist_file:
                plist = plistlib.load(plist_file)
        except (OSError, plistlib.InvalidFileException, TypeError, ValueError) as error:
            raise DockStateError(
                "could not read Dock plist {0!r}: {1}".format(plist_path, error)
            ) from error
        if not isinstance(plist, dict):
            raise DockStateError("Dock plist {0!r} is not a dictionary".format(plist_path))

        for tile in plist.get("persistent-others", []):
            tile_data = tile.get("tile-data", {})
            url = tile_data.get("file-data", {}).get("_CFURLString")
            if not url:
                continue
            options[normalize_location(url)] = {
                "display": DISPLAY_VALUES.get(tile_data.get("displayas", 0), "unknown"),
                "view": VIEW_VALUES.get(tile_data.get("viewas", 0), "unknown"),
                "sort": SORT_VALUES.get(tile_data.get("arrangement", 1), "unknown"),
            }
    return options


def current_items(module: AnsibleModule, dockutil: str) -> List[Dict[str, Any]]:
    try:
        rows = parse_dockutil_output(run_dockutil(module, [dockutil, "--list"]))
    except ValueError as error:
        raise DockStateError(str(error)) from error

    presentation = folder_options([row["plist"] for row in rows if row["plist"]])
    return [
        {
            "name": row["name"],
            "path": row["path"],
            "section": row["section"],
            "options": presentation.get(row["path"], {}),
        }
        for row in rows
    ]


def desired_items(module: AnsibleModule) -> List[Dict[str, Any]]:
    desired = []
    seen = set()
    for index, item in enumerate(module.params["items"]):
        path = normalize_location(item["path"])
        options = {
            key: item[key] for key in ("display", "view", "sort") if item.get(key) is not None
        }
        if path in seen:
            module.fail_json(msg="items[{0}] duplicates Dock path {1!r}".format(index, path))
        seen.add(path)
        if options and item["section"] != "others":
            module.fail_json(
                msg="items[{0}] uses folder presentation outside section=others".format(index)
            )
        if options and urlsplit(path).scheme not in ("", "file"):
            module.fail_json(msg="items[{0}] uses folder presentation for a URL".format(index))
        desired.append(
            {
                "name": item.get("name"),
                "path": path,
                "section": item["section"],
                "options": options,
            }
        )
    return desired


def add_arguments(dockutil: str, item: Mapping[str, Any]) -> List[str]:
    argv = [dockutil, "--add", item["path"], "--position", "end"]
    if item["section"] != "apps":
        argv.extend(["--section", item["section"]])
    argv.extend(dock_option_arguments(item.get("options", {})))
    argv.append("--no-restart")
    return argv


def rebuild(module: AnsibleModule, dockutil: str, items: List[Mapping[str, Any]]) -> None:
    run_dockutil(module, [dockutil, "--remove", "all", "--no-restart"])
    for item in items:
        run_dockutil(module, add_arguments(dockutil, item))


def restore(
    module: AnsibleModule, dockutil: str, previous: List[Mapping[str, Any]]
) -> Tuple[bool, Optional[DockCommandError]]:
    try:
        rebuild(module, dockutil, previous)
    except DockCommandError as error:
        return False, error
    return True, None


def public_items(items: List[Mapping[str, Any]]) -> List[Dict[str, Any]]:
    return [
        {
            "name": item.get("name"),
            "path": item["path"],
            "section": item["section"],
            "options": dict(item.get("options", {})),
        }
        for item in items
    ]


def missing_filesystem_paths(items: List[Mapping[str, Any]]) -> List[str]:
    return [
        item["path"]
        for item in items
        if not urlsplit(item["path"]).scheme and not Path(item["path"]).exists()
    ]


def fail_for_dock_error(module: AnsibleModule, error: DockError, **kwargs: Any) -> None:
    failure = {"msg": str(error)}
    failure.update(kwargs)
    if isinstance(error, DockCommandError):
        failure.update(
            {
                "command": error.argv,
                "rc": error.rc,
                "stdout": error.stdout,
                "stderr": error.stderr,
            }
        )
    module.fail_json(**failure)


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
                    "display": {"type": "str", "choices": ["stack", "folder"]},
                    "view": {"type": "str", "choices": ["auto", "fan", "grid", "list"]},
                    "sort": {
                        "type": "str",
                        "choices": ["name", "dateadded", "datemodified", "datecreated", "kind"],
                    },
                },
            }
        },
        supports_check_mode=True,
    )

    desired = desired_items(module)
    dockutil = module.get_bin_path("dockutil", required=not module.check_mode)
    if dockutil is None:
        after = public_items(desired)
        module.exit_json(
            changed=True,
            items=[],
            paths=[],
            msg="dockutil is not installed; the Dock cannot be inspected in check mode",
            diff={"before": None, "after": after},
        )

    try:
        current = current_items(module, dockutil)
    except DockError as error:
        fail_for_dock_error(module, error, changed=False)
    before = public_items(current)
    after = public_items(desired)
    changed = not dock_states_match(current, desired)
    result = {
        "changed": changed,
        "items": before if module.check_mode else after,
        "paths": [item["path"] for item in (current if module.check_mode else desired)],
        "diff": {"before": before, "after": after},
    }
    if not changed or module.check_mode:
        module.exit_json(**result)

    missing = missing_filesystem_paths(desired)
    if missing:
        module.fail_json(
            msg="Refusing to rebuild the Dock because desired filesystem items do not exist",
            changed=False,
            missing=missing,
        )

    try:
        rebuild(module, dockutil, desired)
        persisted = current_items(module, dockutil)
        if not dock_states_match(persisted, desired):
            raise DockStateError(
                "Dock state did not match the requested state after rebuilding"
            )
    except DockError as error:
        rollback, rollback_error = restore(module, dockutil, current)
        failure = {
            "changed": True,
            "rollback": rollback,
        }
        if rollback_error is not None:
            failure["rollback_error"] = {
                "command": rollback_error.argv,
                "rc": rollback_error.rc,
                "stdout": rollback_error.stdout,
                "stderr": rollback_error.stderr,
            }
        fail_for_dock_error(module, error, **failure)

    module.exit_json(**result)


if __name__ == "__main__":
    main()
