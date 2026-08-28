---
title: Dotfiles
description: A reproducible macOS and Linux workstation built with Ansible and chezmoi.
---

<section class="docs-hero" markdown>
  <p class="section-eyebrow">Personal workstation · documented publicly</p>
  <h1>A workstation I can rebuild.<span class="hero-cursor" aria-hidden="true"></span></h1>
  <p class="hero-copy">This repository turns a fresh macOS or Debian-based Linux machine into my development environment. Ansible, the automation engine, configures the system; chezmoi, the dotfile manager, puts the files in place.</p>
  <div class="hero-actions">
    <a class="primary-link" href="/setup/">Read the setup guide →</a>
    <a class="secondary-link" href="https://github.com/shmileee/dotfiles">Browse the repository ↗</a>
  </div>
</section>

<details class="concept-primer" markdown>
<summary>New to dotfiles? Start here</summary>
<dl class="concept-primer__terms">
  <div><dt>Dotfiles</dt><dd>Configuration files that store how command-line tools and applications behave.</dd></div>
  <div><dt>Ansible</dt><dd>Automation that installs software and applies machine settings in a repeatable order.</dd></div>
  <div><dt>chezmoi</dt><dd>A tool that safely renders and places configuration files in your home directory.</dd></div>
  <div><dt>Role</dt><dd>A focused group of Ansible tasks responsible for one tool or system area.</dd></div>
  <div><dt>Homebrew</dt><dd>A package manager used here to install command-line tools and macOS applications.</dd></div>
</dl>
</details>

## At a glance

<div class="fact-grid">
  <div>
    <span>Platforms</span>
    <strong>macOS + Debian-based Linux</strong>
  </div>
  <div>
    <span>Orchestration</span>
    <strong>Ansible</strong>
  </div>
  <div>
    <span>Dotfile manager</span>
    <strong>chezmoi</strong>
  </div>
  <div>
    <span>Package layer</span>
    <strong>Homebrew + apt</strong>
  </div>
</div>

The result is an opinionated terminal-first environment built around fish,
tmux, Alacritty, Neovim, mise, Git tools, and a curated set of command-line
utilities. On macOS, it also installs desktop applications and applies personal
system defaults.

!!! warning "This is a personal configuration"

    The playbook changes the login shell, applies dotfiles with `--force`, and
    modifies macOS preferences. Read the [setup guide](setup.md)
    before running it on a machine with configuration you want to keep.

## How the pieces fit together

<ol class="install-flow">
  <li>
    <span>01</span>
    <div>
      <strong>Bootstrap</strong>
      <p><a class="repo-path" href="https://github.com/shmileee/dotfiles/blob/master/scripts/setup.sh"><code>scripts/setup.sh</code></a> chooses the macOS or Linux path and prepares the machine.</p>
    </div>
  </li>
  <li>
    <span>02</span>
    <div>
      <strong>Install prerequisites</strong>
      <p>On Linux, the script installs the required apt packages; on both platforms, it prepares Homebrew and Ansible.</p>
    </div>
  </li>
  <li>
    <span>03</span>
    <div>
      <strong>Configure the workstation</strong>
      <p>Ansible runs focused roles for packages, fonts, fish, mise, Neovim, Rancher Desktop, tmux, and system defaults.</p>
    </div>
  </li>
  <li>
    <span>04</span>
    <div>
      <strong>Apply the dotfiles</strong>
      <p>chezmoi renders the files in <a class="repo-path" href="https://github.com/shmileee/dotfiles/tree/master/config"><code>config/</code></a> for the current operating system and architecture.</p>
    </div>
  </li>
</ol>

## Choose what you need

<div class="doc-card-grid">
  <a href="/setup/">
    <span>01 · Start here</span>
    <strong>Set up or customize a machine</strong>
    <p>Review the changes, choose an installation path, and learn how to reapply the configuration.</p>
  </a>
  <a href="/shortcuts/">
    <span>02 · Reference</span>
    <strong>Find a keyboard shortcut</strong>
    <p>Look up bindings for macOS, Alacritty, tmux, and Neovim.</p>
  </a>
  <a href="/opencode/">
    <span>03 · AI tooling</span>
    <strong>Configure OpenCode + OmO</strong>
    <p>Set up local secrets, corporate overlays, model routing, and contextual notifications.</p>
  </a>
</div>

## Design principles

- **Repeatable over clever.** Repeated runs should converge on the same state.
- **Visible over magical.** Package lists, roles, and managed files stay in the repository.
- **Portable where practical.** Shared behavior works on macOS and Linux; platform-specific changes stay explicit.
- **Personal by design.** This is a working environment, not a universal starter kit.

The implementation is tested continuously on macOS and in an Ubuntu-based
container. The container is useful for validating the Linux path, but it does
not reproduce macOS applications or system preferences.
