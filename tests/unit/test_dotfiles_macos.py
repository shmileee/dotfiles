from __future__ import annotations

import importlib
import io
import itertools
import json
import plistlib
import sys
import tempfile
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

DOCK_PLIST = "/Users/me/Library/Preferences/com.apple.dock.plist"


def load_dock_items():
    """Import the Dock module with its module_utils dependency aliased."""
    with patch.dict(
        sys.modules,
        {"ansible.module_utils.dotfiles_macos": sys.modules["dotfiles_macos"]},
    ):
        return importlib.import_module("dock_items")


def dock_list_output(rows):
    """Render dockutil's tab-delimited --list format."""
    sections = {"apps": "persistentApps", "others": "persistentOthers"}
    return "".join(
        "{0}\t{1}\t{2}\t{3}\n".format(
            Path(path).name, path, sections[section], DOCK_PLIST
        )
        for path, section in rows
    )


def dock_domain(tiles):
    """Render an exported Dock domain holding the given folder tiles."""
    return plistlib.dumps(
        {
            "persistent-others": [
                {
                    "tile-type": "directory-tile",
                    "tile-data": dict(
                        {"file-data": {"_CFURLString": url}}, **keys
                    ),
                }
                for url, keys in tiles
            ]
        }
    )


class FakeDock:
    """Serves one --list and one defaults export per queued observation."""

    def __init__(self, observations, failing_add=None):
        self.observations = list(observations)
        self.failing_add = failing_add
        self.index = 0
        self.commands = []

    def observation(self):
        return self.observations[min(self.index, len(self.observations) - 1)]

    def run_command(self, argv, **kwargs):
        self.commands.append(list(argv))
        if argv[0] == "dockutil" and argv[1:] == ["--list"]:
            return 0, dock_list_output(self.observation()[0]), ""
        if argv[0] == "defaults":
            tiles = self.observation()[1]
            self.index += 1
            return 0, dock_domain(tiles), b""
        if self.failing_add is not None and argv[1:3] == [
            "--add",
            self.failing_add,
        ]:
            return 1, "", "dockutil: could not add item"
        return 0, "", ""


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

    def test_prefers_the_native_view_key_over_the_non_native_one(self):
        module = load_dock_items()
        for showas, view in ((0, "auto"), (1, "fan"), (2, "grid"), (3, "list")):
            with self.subTest(showas=showas):
                # Given native presentation and a conflicting non-native key.
                domain = {
                    "persistent-others": [
                        {
                            "tile-data": {
                                "file-data": {
                                    "_CFURLString": "file:///Users/me/Downloads/"
                                },
                                "showas": showas,
                                "viewas": 3,
                                "displayas": 1,
                                "arrangement": 2,
                            }
                        }
                    ]
                }
                # When the folder presentation is decoded.
                options = module.folder_options(domain)
                # Then the key dockutil actually writes decides the view.
                self.assertEqual(
                    options["/Users/me/Downloads"],
                    {
                        "view": view,
                        "display": "folder",
                        "sort": "dateadded",
                    },
                )

    def test_ignores_tiles_without_a_filesystem_url(self):
        module = load_dock_items()
        domain = {
            "persistent-others": [
                {"tile-data": {"file-data": {}}},
                {"tile-data": "not a mapping"},
                "not a tile",
            ]
        }
        self.assertEqual(module.folder_options(domain), {})


class DockModuleTest(unittest.TestCase):
    def setUp(self):
        home = tempfile.TemporaryDirectory()
        self.addCleanup(home.cleanup)
        root = Path(home.name)
        app = root / "A.app"
        app.mkdir()
        downloads = root / "Downloads"
        downloads.mkdir()
        self.app = str(app)
        self.downloads = str(downloads)
        self.items = [
            {"name": "A", "path": self.app},
            {
                "name": "Downloads",
                "path": self.downloads,
                "section": "others",
                "view": "grid",
                "display": "stack",
                "sort": "dateadded",
            },
        ]
        self.settled = (
            [(self.app, "apps"), (self.downloads, "others")],
            [
                (
                    "file://{0}/".format(self.downloads),
                    {"showas": 2, "displayas": 0, "arrangement": 2},
                )
            ],
        )
        self.empty = ([], [])

    def run_module(self, dock, clock_step=0.1):
        module = load_dock_items()
        arguments = {"ANSIBLE_MODULE_ARGS": {"items": self.items}}
        # The fake clock must advance so a Dock that never converges trips the
        # verification deadline and fails the test instead of looping forever.
        clock = itertools.count(0.0, clock_step)
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
                side_effect=lambda name, **kwargs: name,
            ),
            patch.object(
                module.AnsibleModule,
                "run_command",
                side_effect=dock.run_command,
            ),
            patch.object(module, "time") as fake_time,
            redirect_stdout(output),
            self.assertRaises(SystemExit) as exit_result,
        ):
            fake_time.monotonic.side_effect = lambda: next(clock)
            module.main()
        return (
            exit_result.exception.code,
            json.loads(output.getvalue()),
            fake_time,
        )

    def test_reads_presentation_from_the_preference_domain(self):
        # Given a Dock that needs rebuilding and then reports the request.
        dock = FakeDock([self.empty, self.settled])
        # When the module reconciles the Dock.
        code, result, _ = self.run_module(dock)
        # Then it verifies through the domain, never the plist file on disk.
        self.assertEqual(code, 0, result)
        self.assertTrue(result["changed"])
        self.assertIn(
            ["defaults", "export", "com.apple.dock", "-"], dock.commands
        )
        self.assertEqual(
            [
                argv
                for argv in dock.commands
                if argv[0] == "defaults" and DOCK_PLIST in argv
            ],
            [],
        )

    def test_waits_for_the_dock_to_report_the_state_twice(self):
        # Given a restarted Dock that settles only after a stale observation.
        dock = FakeDock([self.empty, self.empty, self.settled])
        # When the module reconciles the Dock.
        code, result, fake_time = self.run_module(dock)
        # Then it re-observed instead of failing on the stale generation.
        self.assertEqual(code, 0, result)
        self.assertTrue(result["changed"])
        self.assertGreaterEqual(fake_time.sleep.call_count, 2)

    def test_reports_observed_and_expected_when_the_dock_never_settles(self):
        # Given a Dock that never reports the requested state.
        dock = FakeDock([self.empty])
        # When verification runs out of time.
        code, result, _ = self.run_module(dock, clock_step=100.0)
        # Then the failure carries the mismatch instead of only asserting one.
        self.assertEqual(code, 1, result)
        self.assertIn("did not match", result["msg"])
        self.assertEqual(result["observed"], [])
        self.assertEqual(
            [item["path"] for item in result["expected"]],
            [self.app, self.downloads],
        )
        self.assertFalse(result["rollback"])

    def test_verifies_rollback_after_a_failed_dockutil_command(self):
        # Given an add that fails partway through the rebuild.
        dock = FakeDock([self.empty], failing_add=self.downloads)
        # When the module rolls the Dock back.
        code, result, _ = self.run_module(dock)
        # Then rollback is claimed only because the previous state returned.
        self.assertEqual(code, 1, result)
        self.assertTrue(result["rollback"])
        self.assertNotIn("rollback_error", result)


if __name__ == "__main__":
    unittest.main()
