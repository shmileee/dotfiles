# Hotkeys

All _"system-wide"_ keyboard shortcuts for macOS are bound using builtin
functionality. The shortcuts are set in
[`config.yaml`](https://github.com/shmileee/dotfiles/blob/master/scripts/common/ansible/config.yaml)
as a `darwin_hotkeys` map that has the following structure:

- `<system keycode>`:
    - parameters: `<keyboard keys in ascii>`
    - enabled: `<boolean that indicates whether shortcut is enabled>`

Where `<system keycode>` is the `int` UID for the feature in _System Preferences
- Keyboard - Shortcuts_, e.g.: _"Show Spotlight search"_ corresponds to `64`.

### Key Bindings

The following keybindings are available: 

| Key Combination | Action                         |
|:---------------:|--------------------------------|
| ++cmd+g++   | Show Spotlight search. |
| ++cmd+space++   | Select the next source in input menu. |

!!! note
    `community.general.osx_defaults` Ansible collection [does not
    support](https://github.com/ansible-collections/community.general/pull/3420)
    modifying system shortcuts yet. This is why I use `ansible.builtin.command`
    to accomplish the desired result, which is not idempotent.

## Read More
- [What do the parameter values in `AppleSymbolicHotKeys` plist dict
  represent?](https://microeducate.tech/what-do-the-parameter-values-in-applesymbolichotkeys-plist-dict-represent/)
