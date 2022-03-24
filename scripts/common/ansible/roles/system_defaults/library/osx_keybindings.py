#!/usr/bin/env python3

from __future__ import (absolute_import, division, print_function,
                        unicode_literals)

import collections
import itertools
import operator
import plistlib
import re

from ansible.module_utils.basic import AnsibleModule

# Most keys can be taken from the USB spec's "HID Usage Tables". Apple seems to
# represent the keys with their "usage page" shifted left 32 bits, then or'ed
# with the key code.
#
# The fn key, though, is special, because it isn't defined by the USB spec as
# far as I know.  Instead, Apple seems to have two versions of the fn key in
# vendor-specific pages.  The first is in page kHIDPage_AppleVendorKeyboard
# (0xff01), the other in page kHIDPage_AppleVendorTopCase (0x00ff).  In both
# pages, the fn key is code 3.
#
# References:
# https://developer.apple.com/library/archive/technotes/tn2450/_index.html
# https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-1035.41.2/IOHIDFamily/AppleHIDUsageTables.h.auto.html
# src/share/apple_hid_usage_tables.hpp in the Karabiner Elements source
# /System/Library/Frameworks/IOKit.framework/Versions/A/Headers/hid/IOHIDUsageTables.h

MASK_USB_KEYBOARD = 7 << 32
MASK_APPLE_KEYBOARD = 0xFF01 << 32
MASK_APPLE_TOP_CASE = 0x00FF << 32

KEY_CODE_TO_NAME = {
    MASK_USB_KEYBOARD | 0x29: "escape",
    MASK_USB_KEYBOARD | 0x39: "caps_lock",
    MASK_USB_KEYBOARD | 0xE0: "left_control",
    MASK_USB_KEYBOARD | 0xE4: "right_control",
    MASK_USB_KEYBOARD | 0xE1: "left_shift",
    MASK_USB_KEYBOARD | 0xE5: "right_shift",
    MASK_USB_KEYBOARD | 0xE2: "left_option",
    MASK_USB_KEYBOARD | 0xE6: "right_option",
    MASK_USB_KEYBOARD | 0xE3: "left_command",
    MASK_USB_KEYBOARD | 0xE7: "right_command",
    MASK_APPLE_KEYBOARD | 0x03: "kb_fn",
    MASK_APPLE_TOP_CASE | 0x03: "top_case_fn",
}

KEY_NAME_TO_CODE = {name: code for code, name in list(KEY_CODE_TO_NAME.items())}

KEY_NAME_ALIASES = {
    # Left/right order important here, see comment in set_modifier_mappings.
    "control": ("left_control", "right_control"),
    "shift": ("left_shift", "right_shift"),
    "option": ("left_option", "right_option"),
    "command": ("left_command", "right_command"),
    "fn": ("kb_fn", "top_case_fn"),
}
KEY_NAME_ALIASES.update((name, (name,)) for name in KEY_NAME_TO_CODE)


class OSXKeybindingsException(Exception):
    def __init__(self, msg):
        self.message = msg


class OSXKeybindings(object):
    def __init__(self, module, **kwargs):
        self.module = module
        self.source_key = kwargs["source_key"]
        self.destination_key = kwargs["destination_key"]
        self.message = None

    def _exec(self, cmd, run_in_check_mode=False, check_rc=True):
        if not self.module.check_mode or (self.module.check_mode and run_in_check_mode):
            rc, out, _ = self.module.run_command(cmd, check_rc=check_rc)
            if rc != 0:
                raise OSXKeybindingsException(
                    "An error occurred while executing {cmd}: {out}"
                )
            return out
        return ""

    def get_keyboard_ids(self):
        hidutil_out = self._exec(["hidutil", "list", "-m", "keyboard"])
        lines = iter(hidutil_out.splitlines())
        for line in lines:
            if line.lower().strip() == "devices:":
                break
        else:
            raise OSXKeybindingsException('Didn\'t find "Devices:" in hidutil output')
        for line in lines:
            fields = line.split()
            if all(
                field in fields
                for field in ["VendorID", "ProductID", "UsagePage", "Usage"]
            ):
                break
        else:
            raise OSXKeybindingsException("Didn't find")
        num_fields = len(fields)
        type_getter = operator.itemgetter(
            fields.index("UsagePage"), fields.index("Usage")
        )
        id_getter = operator.itemgetter(
            fields.index("VendorID"), fields.index("ProductID")
        )
        keyboards = set()
        for line in lines:
            if not line:
                break
            fields = line.split(None, num_fields)
            if len(fields) < num_fields:
                continue
            # Actually, this should never be false since we specified "-m
            # keyboard", but let's be on our guard, I guess.
            if type_getter(fields) == ("1", "6"):
                keyboard_id = tuple(int(val, 16) for val in id_getter(fields))
                # 05AC:8600 is the Touch Bar, according to Karabiner Elements
                # sources.  We can't remap that here (AFAIK).
                if keyboard_id != (0x5AC, 0x8600):
                    keyboards.add(keyboard_id)
        return keyboards

    def read_modifier_mappings(self):
        plist_xml = self._exec(
            ["defaults", "-currentHost", "export", "-g", "-"]
        ).encode("utf-8")
        plist = plistlib.loads(plist_xml)
        keyboards = collections.defaultdict(dict)
        for key, val in list(plist.items()):
            match = re.search(
                r"^com\.apple\.keyboard\.modifiermapping\.(\d+)-(\d+)-0$", key
            )
            if match:
                vendor_id = int(match.group(1))
                product_id = int(match.group(2))
                keyboard = (vendor_id, product_id)
                for mapping in val:
                    # Sometimes these values are <real> instead of <integer>.
                    src = int(mapping["HIDKeyboardModifierMappingSrc"])
                    dst = int(mapping["HIDKeyboardModifierMappingDst"])
                    keyboards[keyboard][src] = dst
        return keyboards

    def set_modifier_mappings(self, keyboards=None):
        needs_changes = False
        msg = []

        if keyboards is None:
            keyboards = self.get_keyboard_ids()

        code_mappings = {}
        if self.source_key in ("escape", "caps_lock", "fn"):
            # Apple seems like using the right variant in these cases, rather
            # than the left.
            self.destination_key = KEY_NAME_ALIASES[self.destination_key][-1]
        try:
            code_mappings.update(
                (KEY_NAME_TO_CODE[src_name], KEY_NAME_TO_CODE[dst_name])
                for src_name, dst_name in itertools.product(
                    KEY_NAME_ALIASES[self.source_key],
                    KEY_NAME_ALIASES[self.destination_key],
                )
            )
        except KeyError as k:
            raise OSXKeybindingsException(f"{k} is not a valid keyboard mapping.")

        all_current_mappings = self.read_modifier_mappings()
        for keyboard in keyboards:
            kbd_mappings = all_current_mappings[keyboard]
            keyboard_name = "%04X:%04X" % keyboard
            for src_code, dst_code in list(code_mappings.items()):
                if kbd_mappings.get(src_code) != dst_code:
                    msg.append(
                        f"Keyboard {keyboard_name}: Changing {KEY_CODE_TO_NAME[src_code]} -> {KEY_CODE_TO_NAME[dst_code]}"
                    )
                    kbd_mappings[src_code] = dst_code
                    needs_changes = True
            if needs_changes:
                plist = [
                    {
                        "HIDKeyboardModifierMappingSrc": src_code,
                        "HIDKeyboardModifierMappingDst": dst_code,
                    }
                    for src_code, dst_code in list(kbd_mappings.items())
                ]
                msg.append(
                    "Modifier changes will not work until you log out and back in."
                )
                key = "com.apple.keyboard.modifiermapping.%d-%d-0" % keyboard
                defaults_cmd = [
                    "defaults",
                    "-currentHost",
                    "write",
                    "-g",
                    key,
                    plistlib.dumps(plist).decode("utf-8"),
                ]
                msg.append(self._exec(defaults_cmd))

        return (needs_changes, msg)


def main():
    module_args = dict(
        source_key=dict(type="str", required=False),
        destination_key=dict(type="str", required=False),
    )

    module = AnsibleModule(argument_spec=module_args, supports_check_mode=False)
    result = dict()
    source_key = module.params["source_key"]
    destination_key = module.params["destination_key"]
    changed = False

    keyboard_modifier = OSXKeybindings(
        module,
        source_key=source_key,
        destination_key=destination_key,
    )
    try:
        changed, message = keyboard_modifier.set_modifier_mappings()
        result["changed"] = changed
        if message:
            result["msg"] = "\n".join(message)
        module.exit_json(**result)
    except OSXKeybindingsException as e:
        module.fail_json(msg=e.message)


if __name__ == "__main__":
    main()
