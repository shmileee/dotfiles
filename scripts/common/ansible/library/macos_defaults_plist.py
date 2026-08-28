#!/usr/bin/python

from __future__ import annotations

DOCUMENTATION = r"""
---
module: macos_defaults_plist
short_description: Reconcile a structured macOS preference value
description:
  - Reads a defaults domain as a plist instead of parsing human-readable output.
  - Replaces scalar and collection values or shallow-merges dictionary members.
  - Verifies the persisted value after every change.
options:
  domain:
    description: Defaults domain to manage.
    type: str
    required: true
  key:
    description: Preference key to manage.
    type: str
    required: true
  value:
    description: Desired plist-compatible value.
    type: raw
    required: true
  value_type:
    description: Plist type used to normalize and write O(value).
    choices: [string, bool, int, float, array, dict]
    type: str
    required: true
  current_host:
    description: Address the current-host preference domain.
    type: bool
    default: false
  dict_mode:
    description:
      - Controls dictionary reconciliation.
      - V(replace) makes the complete dictionary match O(value).
      - V(merge) preserves keys not present in O(value).
    choices: [replace, merge]
    type: str
    default: replace
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
- name: Merge symbolic hotkeys while preserving unrelated shortcuts
  macos_defaults_plist:
    domain: com.apple.symbolichotkeys
    key: AppleSymbolicHotKeys
    value_type: dict
    dict_mode: merge
    value:
      "64":
        enabled: true

- name: Configure the current host's modifier mapping
  macos_defaults_plist:
    domain: NSGlobalDomain
    current_host: true
    key: com.apple.keyboard.modifiermapping.0-0-0
    value_type: array
    value:
      - HIDKeyboardModifierMappingSrc: 30064771129
        HIDKeyboardModifierMappingDst: 30064771113
"""

RETURN = r"""
before:
  description: Preference state before reconciliation.
  returned: always
  type: dict
  contains:
    exists:
      description: Whether the preference key existed before reconciliation.
      type: bool
      returned: always
    value:
      description: Previous preference value.
      type: raw
      returned: when the key exists
after:
  description: Expected or persisted preference state after reconciliation.
  returned: always
  type: dict
  contains:
    exists:
      description: Whether the preference key is expected to exist after reconciliation.
      type: bool
      returned: always
    value:
      description: Expected or persisted preference value.
      type: raw
      returned: always
"""

import plistlib
from typing import Any, Dict, List

from ansible.module_utils.basic import AnsibleModule
from ansible.module_utils.dotfiles_macos import (
    json_safe_plist,
    merged_mapping,
    normalize_plist_value,
    plist_fragment,
)


MISSING = object()


def preference_state(value: Any) -> Dict[str, Any]:
    if value is MISSING:
        return {"exists": False}
    return {"exists": True, "value": json_safe_plist(value)}


def defaults_argv(defaults: str, current_host: bool) -> List[str]:
    argv = [defaults]
    if current_host:
        argv.append("-currentHost")
    return argv


def export_domain(module: AnsibleModule, defaults: str) -> Dict[str, Any]:
    argv = defaults_argv(defaults, module.params["current_host"])
    argv.extend(["export", module.params["domain"], "-"])
    rc, stdout, stderr = module.run_command(argv, encoding=None)
    stderr_text = stderr.decode("utf-8", "replace")
    if rc != 0:
        missing_markers = ("does not exist", "not found", "domain/default pair")
        if rc == 1 and any(marker in stderr_text.lower() for marker in missing_markers):
            return {}
        module.fail_json(
            msg="Could not export defaults domain",
            command=argv,
            rc=rc,
            stderr=stderr_text,
        )

    try:
        domain = plistlib.loads(stdout)
    except (plistlib.InvalidFileException, TypeError, ValueError) as error:
        module.fail_json(msg="Could not parse exported defaults domain: {0}".format(error))
    if not isinstance(domain, dict):
        module.fail_json(msg="Exported defaults domain is not a dictionary")
    return domain


def write_arguments(value: Any, value_type: str) -> List[str]:
    if value_type == "dict":
        return ["-dict"] + [
            part for key, item in value.items() for part in (str(key), plist_fragment(item))
        ]
    if value_type == "array":
        return ["-array"] + [plist_fragment(item) for item in value]
    serialized = str(value).lower() if value_type == "bool" else str(value)
    return ["-{0}".format(value_type), serialized]


def write_preference(module: AnsibleModule, defaults: str, value: Any) -> None:
    argv = defaults_argv(defaults, module.params["current_host"])
    argv.extend(["write", module.params["domain"], module.params["key"]])
    argv.extend(write_arguments(value, module.params["value_type"]))
    rc, stdout, stderr = module.run_command(argv)
    if rc != 0:
        module.fail_json(
            msg="Could not write defaults value",
            command=argv,
            rc=rc,
            stdout=stdout,
            stderr=stderr,
        )


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
            "dict_mode": {"type": "str", "choices": ["replace", "merge"], "default": "replace"},
        },
        supports_check_mode=True,
    )

    if module.params["dict_mode"] == "merge" and module.params["value_type"] != "dict":
        module.fail_json(msg="dict_mode=merge requires value_type=dict")

    try:
        desired_input = normalize_plist_value(module.params["value"], module.params["value_type"])
    except ValueError as error:
        module.fail_json(msg="Invalid value: {0}".format(error))

    defaults = module.get_bin_path("defaults", required=True)
    domain = export_domain(module, defaults)
    current = domain.get(module.params["key"], MISSING)
    desired = (
        merged_mapping(current, desired_input)
        if module.params["value_type"] == "dict" and module.params["dict_mode"] == "merge"
        else desired_input
    )
    changed = current is MISSING or current != desired
    before = preference_state(current)
    after = preference_state(desired)
    result = {
        "changed": changed,
        "before": before,
        "after": after,
        "diff": {"before": before, "after": after},
    }

    if not changed or module.check_mode:
        module.exit_json(**result)

    write_preference(module, defaults, desired)
    persisted = export_domain(module, defaults).get(module.params["key"], MISSING)
    if persisted is MISSING or persisted != desired:
        module.fail_json(
            msg="Preference still differs after reconciliation",
            changed=True,
            before=before,
            after=preference_state(persisted),
            expected=after,
        )
    module.exit_json(**result)


if __name__ == "__main__":
    main()
