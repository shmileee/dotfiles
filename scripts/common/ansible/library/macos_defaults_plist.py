#!/usr/bin/python

from __future__ import annotations

DOCUMENTATION = r"""
---
module: macos_defaults_plist
short_description: Manage macOS defaults containing nested plist values
description:
  - Reads exported defaults with Python's plist parser instead of parsing human-readable output.
  - Replaces a value or merges dictionary members without overwriting unrelated members.
options:
  domain:
    description: Defaults domain.
    type: str
    required: true
  key:
    description: Preference key.
    type: str
    required: true
  value:
    description: Desired plist-compatible value.
    type: raw
    required: true
  value_type:
    description: Type passed to defaults when replacing a value.
    choices: [string, bool, int, float, array, dict]
    type: str
    required: true
  current_host:
    description: Use the current-host preference domain.
    type: bool
    default: false
  dict_mode:
    description: Replace the dictionary or merge only desired members.
    choices: [replace, add]
    type: str
    default: replace
author:
  - dotfiles maintainers
attributes:
  check_mode:
    support: full
"""

EXAMPLES = r"""
- name: Merge symbolic hotkeys
  macos_defaults_plist:
    domain: com.apple.symbolichotkeys
    key: AppleSymbolicHotKeys
    value_type: dict
    dict_mode: add
    value:
      "64":
        enabled: true
"""

RETURN = r"""{}"""

import plistlib
import subprocess
import xml.etree.ElementTree as element_tree

from ansible.module_utils.basic import AnsibleModule


MISSING = object()


def base_argv(module: AnsibleModule) -> list[str]:
    argv = ["/usr/bin/defaults"]
    if module.params["current_host"]:
        argv.append("-currentHost")
    return argv


def exported_domain(module: AnsibleModule) -> dict:
    argv = [*base_argv(module), "export", module.params["domain"], "-"]
    result = subprocess.run(argv, capture_output=True, check=False)
    if result.returncode == 1:
        return {}
    if result.returncode != 0:
        module.fail_json(msg="Could not export defaults domain", rc=result.returncode, stderr=result.stderr.decode())
    try:
        return plistlib.loads(result.stdout)
    except plistlib.InvalidFileException as error:
        module.fail_json(msg=f"Could not parse exported defaults domain: {error}")


def fragment(value: object) -> str:
    document = plistlib.dumps([value], fmt=plistlib.FMT_XML)
    root = element_tree.fromstring(document)
    array = root.find("array")
    if array is None or len(array) != 1:
        raise ValueError("Could not serialize plist value")
    return element_tree.tostring(array[0], encoding="unicode")


def differs(current: object, desired: object, value_type: str, dict_mode: str) -> bool:
    if current is MISSING:
        return True
    if value_type == "dict" and dict_mode == "add":
        return not isinstance(current, dict) or any(current.get(key, MISSING) != value for key, value in desired.items())
    return current != desired


def normalized_value(value: object, value_type: str) -> object:
    if value_type == "string":
        return str(value)
    if value_type == "bool":
        return bool(value)
    if value_type == "int":
        return int(value)
    if value_type == "float":
        return float(value)
    return value


def write_value(module: AnsibleModule) -> None:
    value = module.params["value"]
    value_type = module.params["value_type"]
    argv = [*base_argv(module), "write", module.params["domain"], module.params["key"]]
    commands: list[list[str]] = []

    if value_type == "dict" and module.params["dict_mode"] == "add":
        commands = [[*argv, "-dict-add", str(key), fragment(item)] for key, item in value.items()]
    elif value_type == "array":
        commands = [[*argv, "-array", *[fragment(item) for item in value]]]
    elif value_type == "dict":
        flattened = [part for key, item in value.items() for part in (str(key), fragment(item))]
        commands = [[*argv, "-dict", *flattened]]
    else:
        scalar = str(value).lower() if value_type == "bool" else str(value)
        commands = [[*argv, f"-{value_type}", scalar]]

    for command in commands:
        result = subprocess.run(command, capture_output=True, check=False, text=True)
        if result.returncode != 0:
            module.fail_json(msg="Could not write defaults value", rc=result.returncode, stderr=result.stderr)


def main() -> None:
    module = AnsibleModule(
        argument_spec={
            "domain": {"type": "str", "required": True},
            "key": {"type": "str", "required": True},
            "value": {"type": "raw", "required": True},
            "value_type": {
                "type": "str",
                "choices": ["string", "bool", "int", "float", "array", "dict"],
                "required": True,
            },
            "current_host": {"type": "bool", "default": False},
            "dict_mode": {"type": "str", "choices": ["replace", "add"], "default": "replace"},
        },
        supports_check_mode=True,
    )
    domain = exported_domain(module)
    desired = normalized_value(module.params["value"], module.params["value_type"])
    module.params["value"] = desired
    current = domain.get(module.params["key"], MISSING)
    drift = differs(current, desired, module.params["value_type"], module.params["dict_mode"])
    if not drift or module.check_mode:
        module.exit_json(changed=drift)

    write_value(module)
    final = exported_domain(module).get(module.params["key"], MISSING)
    if differs(final, desired, module.params["value_type"], module.params["dict_mode"]):
        module.fail_json(msg="Default still differs after reconciliation", changed=True)
    module.exit_json(changed=True)


if __name__ == "__main__":
    main()
