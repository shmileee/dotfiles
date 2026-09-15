#!/usr/bin/python

from __future__ import annotations

DOCUMENTATION = r"""
---
module: dock_items
short_description: Reconcile the current user's macOS Dock
description:
  - Reconciles the exact ordered set of persistent Dock items.
  - Parses dockutil's tab-delimited output and reads folder presentation from the Dock preference domain.
  - Reads presentation with defaults export because dockutil writes through cfprefsd, which leaves the plist file on disk stale.
  - Validates every requested item before changing the Dock, waits for the restarted Dock to settle, and verifies any rollback.
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
  description: Whether the previous Dock was restored and observed again after a mutation failure.
  returned: on failure after mutation
  type: bool
observed:
  description: Dock items last observed while waiting for the requested state.
  returned: on verification failure
  type: list
  elements: dict
expected:
  description: Dock items the module required the Dock to report.
  returned: on verification failure
  type: list
  elements: dict
"""

import plistlib
import time
from pathlib import Path
from typing import Any, Dict, List, Mapping, Optional, Tuple
from urllib.parse import urlsplit

from ansible.module_utils.basic import AnsibleModule
from ansible.module_utils.dotfiles_macos import (
    dock_rebuild_commands,
    dock_states_match,
    normalize_location,
    parse_dockutil_output,
)


DISPLAY_VALUES = {0: "stack", 1: "folder"}
VIEW_VALUES = {0: "auto", 1: "fan", 2: "grid", 3: "list"}
SORT_VALUES = {
    1: "name",
    2: "dateadded",
    3: "datemodified",
    4: "datecreated",
    5: "kind",
}

DOCK_DOMAIN = "com.apple.dock"
# dockutil returns as soon as it has asked the Dock to terminate, so the
# relaunched Dock can still be rewriting preferences. Wait for the requested
# state to appear twice in a row instead of trusting one immediate read.
VERIFY_TIMEOUT = 10.0
VERIFY_INTERVAL = 0.5
VERIFY_MATCHES = 2


class DockError(Exception):
    pass


class DockCommandError(DockError):
    def __init__(
        self, argv: List[str], rc: int, stdout: str, stderr: str
    ) -> None:
        super().__init__("dockutil command failed")
        self.argv = argv
        self.rc = rc
        self.stdout = stdout
        self.stderr = stderr


class DockStateError(DockError):
    def __init__(
        self, message: str, observed: Optional[List[Dict[str, Any]]] = None
    ) -> None:
        super().__init__(message)
        self.observed = observed


def run_dockutil(module: AnsibleModule, argv: List[str]) -> str:
    rc, stdout, stderr = module.run_command(argv)
    if rc != 0:
        raise DockCommandError(argv, rc, stdout, stderr)
    return stdout


def export_dock_domain(module: AnsibleModule, defaults: str) -> Dict[str, Any]:
    """Read the Dock domain through the layer dockutil writes through.

    dockutil persists with CFPreferences, so cfprefsd holds the authoritative
    state and the plist file on disk lags behind it. Exporting the domain
    keeps reads coherent with those writes.
    """
    argv = [defaults, "export", DOCK_DOMAIN, "-"]
    rc, stdout, stderr = module.run_command(argv, encoding=None)
    if rc != 0:
        raise DockCommandError(
            argv,
            rc,
            stdout.decode("utf-8", "replace"),
            stderr.decode("utf-8", "replace"),
        )
    try:
        domain = plistlib.loads(stdout)
    except (plistlib.InvalidFileException, TypeError, ValueError) as error:
        raise DockStateError(
            "could not parse the exported Dock domain: {0}".format(error)
        ) from error
    if not isinstance(domain, dict):
        raise DockStateError("the exported Dock domain is not a dictionary")
    return domain


def folder_options(domain: Mapping[str, Any]) -> Dict[str, Dict[str, str]]:
    """Decode folder presentation for filesystem tiles in the others section."""
    tiles = domain.get("persistent-others", [])
    if not isinstance(tiles, list):
        raise DockStateError("Dock persistent-others is not an array")

    options = {}
    for tile in tiles:
        tile_data = tile.get("tile-data") if isinstance(tile, dict) else None
        if not isinstance(tile_data, dict):
            continue
        file_data = tile_data.get("file-data")
        url = (
            file_data.get("_CFURLString")
            if isinstance(file_data, dict)
            else None
        )
        if not isinstance(url, str) or not url:
            continue
        options[normalize_location(url)] = {
            "display": DISPLAY_VALUES.get(
                tile_data.get("displayas", 0), "unknown"
            ),
            # dockutil writes the native "showas" key and never writes
            # "viewas", so reading any other key cannot verify a requested
            # view.
            "view": VIEW_VALUES.get(tile_data.get("showas", 0), "unknown"),
            "sort": SORT_VALUES.get(tile_data.get("arrangement", 1), "unknown"),
        }
    return options


def current_items(
    module: AnsibleModule, dockutil: str, defaults: str
) -> List[Dict[str, Any]]:
    try:
        rows = parse_dockutil_output(run_dockutil(module, [dockutil, "--list"]))
    except ValueError as error:
        raise DockStateError(str(error)) from error

    presentation = folder_options(export_dock_domain(module, defaults))
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
            key: item[key]
            for key in ("display", "view", "sort")
            if item.get(key) is not None
        }
        if path in seen:
            module.fail_json(
                msg="items[{0}] duplicates Dock path {1!r}".format(index, path)
            )
        seen.add(path)
        if options and item["section"] != "others":
            module.fail_json(
                msg="items[{0}] uses folder presentation outside section=others".format(
                    index
                )
            )
        if options and urlsplit(path).scheme not in ("", "file"):
            module.fail_json(
                msg="items[{0}] uses folder presentation for a URL".format(
                    index
                )
            )
        desired.append(
            {
                "name": item.get("name"),
                "path": path,
                "section": item["section"],
                "options": options,
            }
        )
    return desired


def rebuild(
    module: AnsibleModule, dockutil: str, items: List[Mapping[str, Any]]
) -> None:
    for arguments in dock_rebuild_commands(dockutil, items):
        run_dockutil(module, arguments)


def verify_dock_state(
    module: AnsibleModule,
    dockutil: str,
    defaults: str,
    desired: List[Mapping[str, Any]],
) -> None:
    """Wait until the Dock reports the requested state twice in a row."""
    deadline = time.monotonic() + VERIFY_TIMEOUT
    matches = 0
    while True:
        observed = current_items(module, dockutil, defaults)
        matches = matches + 1 if dock_states_match(observed, desired) else 0
        if matches >= VERIFY_MATCHES:
            return
        if time.monotonic() >= deadline:
            raise DockStateError(
                "Dock state did not match the requested state after rebuilding",
                observed=observed,
            )
        time.sleep(VERIFY_INTERVAL)


def restore(
    module: AnsibleModule,
    dockutil: str,
    defaults: str,
    previous: List[Mapping[str, Any]],
) -> Tuple[bool, Optional[DockError]]:
    try:
        rebuild(module, dockutil, previous)
        verify_dock_state(module, dockutil, defaults, previous)
    except DockError as error:
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


def fail_for_dock_error(
    module: AnsibleModule, error: DockError, **kwargs: Any
) -> None:
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
                    "section": {
                        "type": "str",
                        "choices": ["apps", "others"],
                        "default": "apps",
                    },
                    "display": {"type": "str", "choices": ["stack", "folder"]},
                    "view": {
                        "type": "str",
                        "choices": ["auto", "fan", "grid", "list"],
                    },
                    "sort": {
                        "type": "str",
                        "choices": [
                            "name",
                            "dateadded",
                            "datemodified",
                            "datecreated",
                            "kind",
                        ],
                    },
                },
            }
        },
        supports_check_mode=True,
    )

    desired = desired_items(module)
    required = not module.check_mode
    dockutil = module.get_bin_path("dockutil", required=required)
    defaults = module.get_bin_path("defaults", required=required)
    unavailable = [
        name
        for name, path in (("dockutil", dockutil), ("defaults", defaults))
        if path is None
    ]
    if unavailable:
        module.exit_json(
            changed=True,
            items=[],
            paths=[],
            msg="{0} is not installed; the Dock cannot be inspected in check mode".format(
                " and ".join(unavailable)
            ),
            diff={"before": None, "after": public_items(desired)},
        )

    try:
        current = current_items(module, dockutil, defaults)
    except DockError as error:
        fail_for_dock_error(module, error, changed=False)
    before = public_items(current)
    after = public_items(desired)
    changed = not dock_states_match(current, desired)
    result = {
        "changed": changed,
        "items": before if module.check_mode else after,
        "paths": [
            item["path"] for item in (current if module.check_mode else desired)
        ],
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
        verify_dock_state(module, dockutil, defaults, desired)
    except DockError as error:
        rollback, rollback_error = restore(module, dockutil, defaults, current)
        failure: Dict[str, Any] = {
            "changed": True,
            "rollback": rollback,
        }
        observed = getattr(error, "observed", None)
        if observed is not None:
            failure["observed"] = public_items(observed)
            failure["expected"] = after
        if rollback_error is not None:
            details: Dict[str, Any] = {"msg": str(rollback_error)}
            if isinstance(rollback_error, DockCommandError):
                details.update(
                    {
                        "command": rollback_error.argv,
                        "rc": rollback_error.rc,
                        "stdout": rollback_error.stdout,
                        "stderr": rollback_error.stderr,
                    }
                )
            failure["rollback_error"] = details
        fail_for_dock_error(module, error, **failure)

    module.exit_json(**result)


if __name__ == "__main__":
    main()
