All **system-wide** keyboard shortcuts for macOS are configured using built-in
functionality. These shortcuts are defined in
[`config.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml)
under the `darwin_hotkeys{}` map, which follows this structure:

- `<system keycode>`:
      - `enabled`: `<true | false>`
      - `value`:
          - `parameters`: `<keyboard keys in ASCII>`
          - `type`: `standard`

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

    The generic `community.general.osx_defaults` module cannot safely reconcile
    every nested preference used here. A repository-local Ansible module reads
    the exported plist as structured data, merges only the configured shortcut
    keys, and supports both idempotent runs and check mode.
