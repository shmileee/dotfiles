#!/usr/bin/python

from __future__ import annotations

DOCUMENTATION = r"""
---
module: command_reconcile
short_description: Reconcile state exposed by a command-line program
description:
  - Runs a read-only probe and compares its structured output with desired state.
  - Runs an apply command only when drift exists, and verifies the result afterward.
  - Supports check mode by probing without invoking the apply command.
options:
  probe_argv:
    description: Probe command and arguments.
    type: list
    elements: str
    required: true
  apply_argv:
    description: Reconciliation command and arguments.
    type: list
    elements: str
    required: true
  comparison:
    description: How probe standard output is compared with desired state.
    choices: [empty, json_empty, lines]
    required: true
    type: str
  desired_lines:
    description: Desired lines when C(comparison=lines).
    type: list
    elements: str
    default: []
  normalize_case:
    description: Compare lines case-insensitively.
    type: bool
    default: false
  sort_lines:
    description: Ignore line ordering during comparison.
    type: bool
    default: false
  environment:
    description: Environment values supplied to both commands.
    type: dict
    default: {}
  probe_failure_means_changed_in_check:
    description: Treat an unavailable probe dependency as predicted drift in check mode.
    type: bool
    default: false
  probe_success_rc:
    description: Probe return codes that represent a readable state.
    type: list
    elements: int
    default: [0]
author:
  - dotfiles maintainers
attributes:
  check_mode:
    support: full
"""

EXAMPLES = r"""
- name: Reconcile mise tools
  command_reconcile:
    probe_argv: [mise, ls, --missing, --json]
    apply_argv: [mise, install]
    comparison: json_empty
"""

RETURN = r"""
probe_stdout:
  description: Standard output from the final probe.
  returned: always
  type: str
"""

import json
import os
import subprocess

from ansible.module_utils.basic import AnsibleModule


def run(argv: list[str], environment: dict[str, str]) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env.update({key: str(value) for key, value in environment.items()})
    return subprocess.run(argv, capture_output=True, check=False, text=True, env=env)


def normalized_lines(lines: list[str], normalize_case: bool, sort_lines: bool) -> list[str]:
    result = [line.strip() for line in lines if line.strip()]
    if normalize_case:
        result = [line.casefold() for line in result]
    return sorted(result) if sort_lines else result


def has_drift(module: AnsibleModule, stdout: str) -> bool:
    comparison = module.params["comparison"]
    if comparison == "empty":
        return bool(stdout.strip())
    if comparison == "json_empty":
        try:
            return bool(json.loads(stdout))
        except json.JSONDecodeError as error:
            module.fail_json(msg=f"Probe did not return valid JSON: {error}", probe_stdout=stdout)

    actual = normalized_lines(
        stdout.splitlines(), module.params["normalize_case"], module.params["sort_lines"]
    )
    desired = normalized_lines(
        module.params["desired_lines"], module.params["normalize_case"], module.params["sort_lines"]
    )
    return actual != desired


def probe(module: AnsibleModule) -> subprocess.CompletedProcess[str] | None:
    try:
        result = run(module.params["probe_argv"], module.params["environment"])
    except FileNotFoundError as error:
        if module.check_mode:
            return None
        module.fail_json(msg=f"Probe executable was not found: {error}")
    if (
        result.returncode not in module.params["probe_success_rc"]
        and module.check_mode
        and module.params["probe_failure_means_changed_in_check"]
    ):
        return None
    if result.returncode not in module.params["probe_success_rc"]:
        module.fail_json(
            msg="Probe command failed",
            rc=result.returncode,
            stdout=result.stdout,
            stderr=result.stderr,
        )
    return result


def main() -> None:
    module = AnsibleModule(
        argument_spec={
            "probe_argv": {"type": "list", "elements": "str", "required": True},
            "apply_argv": {"type": "list", "elements": "str", "required": True},
            "comparison": {
                "type": "str",
                "choices": ["empty", "json_empty", "lines"],
                "required": True,
            },
            "desired_lines": {"type": "list", "elements": "str", "default": []},
            "normalize_case": {"type": "bool", "default": False},
            "sort_lines": {"type": "bool", "default": False},
            "environment": {"type": "dict", "default": {}},
            "probe_failure_means_changed_in_check": {"type": "bool", "default": False},
            "probe_success_rc": {"type": "list", "elements": "int", "default": [0]},
        },
        supports_check_mode=True,
    )

    initial = probe(module)
    if initial is None:
        module.exit_json(changed=True, probe_stdout="", msg="Probe executable is not installed yet")

    drift = has_drift(module, initial.stdout)
    if not drift or module.check_mode:
        module.exit_json(changed=drift, probe_stdout=initial.stdout)

    try:
        applied = run(module.params["apply_argv"], module.params["environment"])
    except FileNotFoundError as error:
        module.fail_json(msg=f"Apply executable was not found: {error}")
    if applied.returncode != 0:
        module.fail_json(
            msg="Apply command failed",
            changed=True,
            rc=applied.returncode,
            stdout=applied.stdout,
            stderr=applied.stderr,
        )

    final = probe(module)
    if final is None or has_drift(module, final.stdout):
        module.fail_json(
            msg="State still differs after reconciliation",
            changed=True,
            probe_stdout="" if final is None else final.stdout,
        )
    module.exit_json(changed=True, probe_stdout=final.stdout, stdout=applied.stdout, stderr=applied.stderr)


if __name__ == "__main__":
    main()
