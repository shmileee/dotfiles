#!/usr/bin/python

from __future__ import annotations

DOCUMENTATION = r"""
---
module: lazy_plugins
short_description: Restore Neovim lazy.nvim plugins from a lock file
description:
  - Compares installed plugin Git revisions with lazy-lock.json.
  - Runs Lazy restore only when plugins are missing or at different revisions.
options:
  lock_file:
    description: Path to lazy-lock.json.
    type: path
    required: true
  plugin_root:
    description: Directory containing lazy.nvim plugin checkouts.
    type: path
    required: true
  active_lock_file:
    description: Lock file used by the active Neovim configuration.
    type: path
    required: true
  install_argv:
    description: Command used to install plugins missing from an empty setup.
    type: list
    elements: str
    required: true
  restore_argv:
    description: Command used to restore the locked plugin state.
    type: list
    elements: str
    required: true
  verify_argv:
    description: Command used to verify that Neovim starts successfully.
    type: list
    elements: str
    required: true
author:
  - dotfiles maintainers
attributes:
  check_mode:
    support: full
"""

EXAMPLES = r"""
- name: Restore Neovim plugins
  lazy_plugins:
    lock_file: ~/.config/nvim/lazy-lock.json
    plugin_root: ~/.local/share/nvim/lazy
    active_lock_file: ~/.config/nvim/lazy-lock.json
    install_argv: [mise, exec, --, nvim, --headless, +Lazy! install, +qa]
    restore_argv: [mise, exec, --, nvim, --headless, +Lazy! restore, +qa]
    verify_argv: [mise, exec, --, nvim, --headless, +qa]
"""

RETURN = r"""
drifted_plugins:
  description: Missing plugins or plugins at the wrong revision.
  returned: always
  type: list
  elements: str
"""

import json
import os
import shutil
import subprocess

from ansible.module_utils.basic import AnsibleModule


def drifted(lock_file: str, plugin_root: str) -> list[str]:
    with open(lock_file, encoding="utf-8") as handle:
        lock = json.load(handle)
    result = []
    for name, metadata in lock.items():
        checkout = os.path.join(plugin_root, name)
        revision = subprocess.run(
            ["git", "-C", checkout, "rev-parse", "HEAD"], capture_output=True, check=False, text=True
        )
        if revision.returncode != 0 or revision.stdout.strip() != metadata["commit"]:
            result.append(name)
    return result


def invoke(module: AnsibleModule, argv: list[str], description: str) -> subprocess.CompletedProcess[str]:
    try:
        result = subprocess.run(argv, capture_output=True, check=False, text=True)
    except FileNotFoundError as error:
        module.fail_json(msg=f"{description} executable was not found: {error}")
    if result.returncode != 0:
        module.fail_json(
            msg=f"{description} failed",
            rc=result.returncode,
            stdout=result.stdout,
            stderr=result.stderr,
        )
    return result


def main() -> None:
    module = AnsibleModule(
        argument_spec={
            "lock_file": {"type": "path", "required": True},
            "plugin_root": {"type": "path", "required": True},
            "active_lock_file": {"type": "path", "required": True},
            "install_argv": {"type": "list", "elements": "str", "required": True},
            "restore_argv": {"type": "list", "elements": "str", "required": True},
            "verify_argv": {"type": "list", "elements": "str", "required": True},
        },
        supports_check_mode=True,
    )
    try:
        initial = drifted(module.params["lock_file"], module.params["plugin_root"])
    except (OSError, ValueError, KeyError) as error:
        module.fail_json(msg=f"Could not inspect lazy.nvim state: {error}")
    if module.check_mode:
        module.exit_json(changed=bool(initial), drifted_plugins=initial)
    if not initial:
        invoke(module, module.params["verify_argv"], "Neovim startup verification")
        module.exit_json(changed=False, drifted_plugins=[])

    invoke(module, module.params["install_argv"], "Lazy install")
    try:
        shutil.copyfile(module.params["lock_file"], module.params["active_lock_file"])
    except OSError as error:
        module.fail_json(msg=f"Could not restore the committed Lazy lock file: {error}")
    invoke(module, module.params["restore_argv"], "Lazy restore")
    final = drifted(module.params["lock_file"], module.params["plugin_root"])
    if final:
        module.fail_json(msg="Plugins still differ after Lazy restore", changed=True, drifted_plugins=final)
    invoke(module, module.params["verify_argv"], "Neovim startup verification")
    module.exit_json(changed=True, drifted_plugins=[])


if __name__ == "__main__":
    main()
