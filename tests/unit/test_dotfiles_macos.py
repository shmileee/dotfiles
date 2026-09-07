from __future__ import annotations

import importlib
import io
import json
import plistlib
import sys
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

from ansible.module_utils import basic

ANSIBLE_DIR = Path(__file__).parents[2] / "bootstrap" / "ansible"
sys.path.insert(0, str(ANSIBLE_DIR / "module_utils"))
sys.path.insert(0, str(ANSIBLE_DIR / "library"))

from dotfiles_macos import (  # noqa: E402
    dock_option_arguments,
    dock_rebuild_commands,
    dock_states_match,
    json_safe_plist,
    merged_mapping,
    normalize_location,
    normalize_plist_value,
    parse_dockutil_output,
    plist_fragment,
)


class PlistHelpersTest(unittest.TestCase):
    def test_reconciles_when_boolean_and_integer_values_differ(self):
        with patch.dict(
            sys.modules,
            {
                "ansible.module_utils.dotfiles_macos": sys.modules[
                    "dotfiles_macos"
                ]
            },
        ):
            module = importlib.import_module("macos_defaults_plist")
        for current, desired, value_type, persisted, changed, failed in (
            (1, True, "bool", True, True, False),
            (0, False, "bool", False, True, False),
            (True, 1, "int", 1, True, False),
            (False, 0, "int", 0, True, False),
            ([1], [True], "array", [True], True, False),
            (
                {"enabled": 0},
                {"enabled": False},
                "dict",
                {"enabled": False},
                True,
                False,
            ),
            (True, True, "bool", True, False, False),
            (1, 1, "int", 1, False, False),
            (
                {"a": 1, "b": True},
                {"b": True, "a": 1},
                "dict",
                {},
                False,
                False,
            ),
            ("old", True, "bool", 1, True, True),
            ("old", [False], "array", [0], True, True),
        ):
            for check_mode in (True, False):
                with self.subTest(
                    current=current, desired=desired, check_mode=check_mode
                ):
                    # Given a real Ansible request and exported preference.
                    arguments = {
                        "ANSIBLE_MODULE_ARGS": {
                            "domain": "test.dotfiles",
                            "key": "value",
                            "value": desired,
                            "value_type": value_type,
                            "_ansible_check_mode": check_mode,
                        }
                    }
                    responses = [
                        (0, plistlib.dumps({"value": current}), b""),
                        (0, "", ""),
                        (0, plistlib.dumps({"value": persisted}), b""),
                    ]
                    output = io.StringIO()
                    with (
                        patch.object(basic, "_ANSIBLE_PROFILE", "legacy"),
                        patch(
                            "ansible.module_utils.basic._ANSIBLE_ARGS",
                            json.dumps(arguments).encode(),
                        ),
                        patch.object(
                            module.AnsibleModule,
                            "get_bin_path",
                            return_value="defaults",
                        ),
                        patch.object(
                            module.AnsibleModule,
                            "run_command",
                            side_effect=responses,
                        ),
                        redirect_stdout(output),
                        self.assertRaises(SystemExit) as exit_result,
                    ):
                        # When the module reconciles the preference.
                        module.main()
                    # Then only genuinely equal plist values are unchanged.
                    self.assertEqual(
                        exit_result.exception.code,
                        int(failed and not check_mode),
                        output.getvalue(),
                    )
                    self.assertEqual(
                        json.loads(output.getvalue())["changed"],
                        changed,
                    )

    def test_normalizes_scalars_without_bool_integer_confusion(self):
        self.assertEqual(normalize_plist_value("7", "int"), 7)
        self.assertEqual(normalize_plist_value(1, "string"), "1")
        self.assertEqual(normalize_plist_value("0.5", "float"), 0.5)
        self.assertIs(normalize_plist_value(False, "bool"), False)
        with self.assertRaisesRegex(ValueError, "cannot be a boolean"):
            normalize_plist_value(True, "int")
        with self.assertRaisesRegex(ValueError, "must be true or false"):
            normalize_plist_value("false", "bool")

    def test_rejects_wrong_collection_types_and_invalid_plists(self):
        with self.assertRaisesRegex(ValueError, "must be a list"):
            normalize_plist_value({}, "array")
        with self.assertRaisesRegex(ValueError, "must be a mapping"):
            normalize_plist_value([], "dict")
        with self.assertRaisesRegex(ValueError, "plist-serializable"):
            normalize_plist_value({"bad": object()}, "dict")

    def test_merges_without_mutating_current_mapping(self):
        current = {"keep": 1, "change": 1}
        desired = merged_mapping(current, {"change": 2})
        self.assertEqual(desired, {"keep": 1, "change": 2})
        self.assertEqual(current, {"keep": 1, "change": 1})

    def test_serializes_nested_plist_fragment(self):
        fragment = plist_fragment({"enabled": True, "values": [1, 2]})
        self.assertIn("<dict>", fragment)
        self.assertIn("<true", fragment)
        self.assertIn("<array>", fragment)

    def test_makes_binary_plist_data_safe_for_ansible_json(self):
        self.assertEqual(
            json_safe_plist({"secureData": b"\xd4\x00", "string": "⌘"}),
            {"secureData": {"__plist_data__": "1AA="}, "string": "⌘"},
        )


class DockHelpersTest(unittest.TestCase):
    def test_normalizes_paths_file_urls_and_network_urls(self):
        self.assertEqual(
            normalize_location("/Applications/Test.app/"),
            "/Applications/Test.app",
        )
        self.assertEqual(
            normalize_location("file:///Users/me/My%20Folder/"),
            "/Users/me/My Folder",
        )
        self.assertEqual(
            normalize_location("HTTPS://example.test/a%20folder/"),
            "https://example.test/a folder/",
        )

    def test_parses_dockutil_rows(self):
        output = (
            "Terminal\t/Applications/Terminal.app\tpersistentApps\t/Users/me/Library/Preferences/com.apple.dock.plist\tcom.apple.Terminal\n"
            "Downloads\tfile:///Users/me/Downloads/\tpersistentOthers\t/Users/me/Library/Preferences/com.apple.dock.plist\t\n"
        )
        self.assertEqual(
            parse_dockutil_output(output),
            [
                {
                    "name": "Terminal",
                    "path": "/Applications/Terminal.app",
                    "section": "apps",
                    "plist": "/Users/me/Library/Preferences/com.apple.dock.plist",
                },
                {
                    "name": "Downloads",
                    "path": "/Users/me/Downloads",
                    "section": "others",
                    "plist": "/Users/me/Library/Preferences/com.apple.dock.plist",
                },
            ],
        )
        with self.assertRaisesRegex(ValueError, "line 1"):
            parse_dockutil_output("not tab delimited")

    def test_preserves_persistent_items_when_recent_apps_are_listed(self):
        # Given a persistent item followed by a valid recent application.
        persistent = "Terminal\t/Applications/Terminal.app\tpersistentApps\t/dock.plist\n"
        recent = "Safari\t/Applications/Safari.app\trecentApps\t/dock.plist\tcom.apple.Safari\n"
        # When dockutil output includes both sections.
        items = parse_dockutil_output(persistent + recent)
        # Then recent applications do not enter persistent reconciliation.
        self.assertEqual(
            items,
            [
                {
                    "name": "Terminal",
                    "path": "/Applications/Terminal.app",
                    "section": "apps",
                    "plist": "/dock.plist",
                }
            ],
        )

    def test_rejects_malformed_rows_when_recent_apps_are_supported(self):
        for row in (
            "Safari\t/Applications/Safari.app\trecentApps",
            "Safari\t/Applications/Safari.app\tunknownApps\t/dock.plist",
        ):
            with (
                self.subTest(row=row),
                self.assertRaisesRegex(ValueError, "line 1"),
            ):
                parse_dockutil_output(row)

    def test_compares_order_and_only_requested_presentation(self):
        current = [
            {"path": "/Applications/A.app", "section": "apps", "options": {}},
            {
                "path": "/Users/me/Downloads",
                "section": "others",
                "options": {
                    "view": "auto",
                    "display": "stack",
                    "sort": "dateadded",
                },
            },
        ]
        desired = [
            {"path": "/Applications/A.app", "section": "apps", "options": {}},
            {
                "path": "/Users/me/Downloads",
                "section": "others",
                "options": {"display": "stack"},
            },
        ]
        self.assertTrue(dock_states_match(current, desired))
        self.assertFalse(dock_states_match(list(reversed(current)), desired))

    def test_generates_options_in_a_stable_order(self):
        self.assertEqual(
            dock_option_arguments(
                {"sort": "dateadded", "display": "stack", "view": "auto"}
            ),
            ["--view", "auto", "--display", "stack", "--sort", "dateadded"],
        )

    def test_restarts_dock_only_after_the_final_batched_mutation(self):
        items = [
            {"path": "/Applications/A.app", "section": "apps", "options": {}},
            {
                "path": "/Users/me/Downloads",
                "section": "others",
                "options": {"display": "stack"},
            },
        ]
        self.assertEqual(
            dock_rebuild_commands("dockutil", items),
            [
                ["dockutil", "--remove", "all", "--no-restart"],
                [
                    "dockutil",
                    "--add",
                    "/Applications/A.app",
                    "--position",
                    "end",
                    "--no-restart",
                ],
                [
                    "dockutil",
                    "--add",
                    "/Users/me/Downloads",
                    "--position",
                    "end",
                    "--section",
                    "others",
                    "--display",
                    "stack",
                ],
            ],
        )
        self.assertEqual(
            dock_rebuild_commands("dockutil", []),
            [["dockutil", "--remove", "all"]],
        )


if __name__ == "__main__":
    unittest.main()
