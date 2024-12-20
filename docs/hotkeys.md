All **system-wide** keyboard shortcuts for macOS are configured using built-in
functionality. These shortcuts are defined in
[`config.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml)
under the `darwin_hotkeys{}` map, which follows this structure:

- `<system keycode>`:
      - `parameters`: `<keyboard keys in ASCII>`
      - `enabled`: `<true | false>`

Here, `<system keycode>` refers to the `int` UID associated with a feature in
_System Preferences → Keyboard → Shortcuts_. For example, the keycode `64`
corresponds to the _"Show Spotlight search"_ shortcut.

### Key Bindings

The following key bindings are currently in-use:

| Key Combination | Action                                   |
| :-------------: | ---------------------------------------- |
|    ++cmd+g++    | Show Spotlight search                    |
|  ++cmd+space++  | Select the next source in the input menu |

!!! note

    The `community.general.osx_defaults` Ansible collection [does not yet
    support](https://github.com/ansible-collections/community.general/pull/3420)
    modifying system shortcuts. Therefore, `ansible.builtin.command` is used
    instead, which achieves the desired result but lacks idempotency.
