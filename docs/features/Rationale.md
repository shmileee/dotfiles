**Rationale**

---

## Goal

The goal is to provide a fully automated development environment that’s both
easy to set up and maintain.

## Why `ansible`?

In my experience, `ansible` is one of the easiest automation tools to learn.
Although it has its share of nuances, its YAML-based configuration is generally
straightforward to understand—even for users with limited knowledge of
`ansible`. It’s almost like reading plain English most of the time.

Additionally, `ansible` is like a Swiss Army knife of orchestration tools. It
can be adapted to a wide range of tasks, some of which might not be supported
by other popular solutions like `NixOS Home Manager`. One of its greatest
strengths is that tasks, when properly described, adhere to the principle of
[idempotency](https://docs.ansible.com/ansible/latest/reference_appendices/glossary.html#term-Idempotency).
This means you can rerun a playbook repeatedly without worrying about
unintended removal or duplication of your files.

In a world full of automation solutions, I simply happen to enjoy using
`ansible` the most.

## Why `chezmoi`?

`chezmoi` is a powerful tool for managing dotfiles. It’s currently one of the
most popular solutions, boasting over 6k stars on GitHub. Before `chezmoi`, I
used `gnu stow`, which worked fine but lacked several features that `chezmoi`
conveniently provides.

Key benefits of `chezmoi` include:

- **Flexible**: Dotfiles can be templates using text/template syntax. While
  `ansible` has Jinja templates, `chezmoi` offers built-in variables for platform
  detection, architecture, hostname, environment variables, and more. Testing
  these templates in `chezmoi` is much simpler—just run `chezmoi execute-template
< file.tmpl`.
- **Portable**: `chezmoi` configurations rely solely on visible, regular files
  and directories, ensuring portability across different version control systems
  and operating systems.
- **Transparent**: Verbose and dry-run modes let you preview changes before
  they’re applied, giving you complete control over what happens in your home
  directory.
- **Practical**: `chezmoi` manages hidden files, directories, private files,
  and executables—essentially all the typical elements of a dotfiles repository.
- **Fast and Easy to Use**: `chezmoi` runs in fractions of a second, and it
  provides commands that simplify most common operations.

By using `chezmoi`, I can adhere to the single-responsibility principle:
managing dotfiles independently from other system configuration tasks.

## Why `LazyVim`?

I used `vim` for years until my configuration ballooned to over 500 lines,
making it a challenge to maintain. My switch to `neovim` was inspired by talks
from [ThePrimagen](https://github.com/ThePrimeagen) and [TJ
DeVries](https://github.com/tjdevries), which also made me realize I didn’t
fully grasp the Lua-based configuration system that `neovim` uses.

It turned out that most of the common keymaps, plugins, and sensible defaults I
was after were already configured by many in the `neovim` community. Enter
`LazyVim`: it provides a community-driven framework for `neovim`, bundling
common plugins and sensible defaults. This allowed me to avoid starting from
scratch and reinventing the wheel. I only needed to add a few extra plugins,
tweak some keybindings, and configure fewer than ten settings to feel
completely at home.

## Why `fish`?

The `fish` ecosystem excels as an interactive shell. While I still write my
scripts in `bash` for portability, the out-of-the-box features in `fish`, such
as autosuggestions and robust tab completions, are too convenient to pass up.
