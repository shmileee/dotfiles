#!/usr/bin/python

from __future__ import annotations

DOCUMENTATION = r"""
---
module: dock_items
short_description: Reconcile the current user's macOS Dock items
description:
  - Uses dockutil's documented tab-delimited list output as structured fields.
  - Rebuilds the Dock only when the ordered item paths differ.
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

import subprocess
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


def current_paths(module: AnsibleModule, dockutil: str) -> list[str]:
    output = invoke(module, [dockutil, "--list"]).stdout
    paths = []
    for line_number, line in enumerate(output.splitlines(), start=1):
        fields = line.split("\t")
        if len(fields) < 2:
            module.fail_json(msg=f"Unexpected dockutil output on line {line_number}: {line!r}")
        path = unquote(urlsplit(fields[1]).path).rstrip("/")
        paths.append(path)
    return paths


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
    desired = [item["path"].rstrip("/") for item in module.params["items"]]
    if dockutil is None:
        module.exit_json(changed=True, paths=[], msg="dockutil is not installed yet")

    current = current_paths(module, dockutil)
    if current == desired or module.check_mode:
        module.exit_json(changed=current != desired, paths=current)

    invoke(module, [dockutil, "--remove", "all", "--no-restart"])
    for item in module.params["items"]:
        argv = [dockutil, "--add", item["path"], "--position", "end", *item["options"]]
        if item["section"] != "apps":
            argv.extend(["--section", item["section"]])
        argv.append("--no-restart")
        invoke(module, argv)

    final = current_paths(module, dockutil)
    if final != desired:
        module.fail_json(msg="Dock still differs after reconciliation", changed=True, paths=final)
    module.exit_json(changed=True, paths=final)


if __name__ == "__main__":
    main()
