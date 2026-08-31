from __future__ import annotations

import sys
import unittest
from pathlib import Path


ANSIBLE_DIR = Path(__file__).parents[2] / "bootstrap" / "ansible"
sys.path.insert(0, str(ANSIBLE_DIR / "module_utils"))

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
