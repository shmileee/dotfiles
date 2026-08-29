---
title: Home
description: A reproducible Apple Silicon macOS workstation and Ubuntu ARM64 integration environment built with Ansible and chezmoi.
tags:
  - Overview
  - macOS
  - Ubuntu
  - Ansible
  - chezmoi
hide:
  - toc
  - tags
---

<section class="docs-hero docs-hero--home" markdown>
  <p class="section-eyebrow">Personal workstation · documented publicly</p>
  <h1>A workstation I can rebuild.<span class="hero-cursor" aria-hidden="true"></span></h1>
  <p class="hero-copy">This repository rebuilds my Apple Silicon macOS workstation and continuously tests the shared setup in Ubuntu 24.04 ARM64. Ansible, the automation engine, configures the system; chezmoi, the dotfile manager, puts the files in place.</p>
  <div class="hero-actions">
    <a class="primary-link" href="/setup/">Read the setup guide →</a>
    <a class="secondary-link" href="https://github.com/shmileee/dotfiles">Browse the repository ↗</a>
  </div>
  <dl class="hero-signals">
    <div><dt>Targets</dt><dd>macOS + Ubuntu</dd></div>
    <div><dt>Automation</dt><dd>Ansible</dd></div>
    <div><dt>Dotfiles</dt><dd>chezmoi</dd></div>
  </dl>
</section>

<section class="context-help-source" hidden data-search-exclude>
<button class="context-help-trigger" type="button" aria-label="Open quick context" aria-controls="context-help" aria-haspopup="dialog" title="Quick context" data-context-open data-context-ui><span aria-hidden="true">?</span></button>
<dialog class="context-help" id="context-help" aria-labelledby="context-help-title" data-context-dialog data-context-ui>
<div class="context-help__panel">
<header class="context-help__header">
  <div><p>Quick context</p><h2 id="context-help-title" data-search-exclude>Terms used on this page</h2></div>
  <button type="button" aria-label="Close quick context" data-context-close><svg viewBox="0 0 16 16" aria-hidden="true" focusable="false"><path d="m4 4 8 8m0-8-8 8" /></svg></button>
</header>
<dl class="context-help__terms">
  <div><dt>Dotfiles</dt><dd>Configuration files that store how command-line tools and applications behave.</dd></div>
  <div><dt>Ansible</dt><dd>Automation that installs software and applies machine settings in a repeatable order.</dd></div>
  <div><dt>chezmoi</dt><dd>A tool that safely renders and places configuration files in your home directory.</dd></div>
  <div><dt>Role</dt><dd>A focused group of Ansible tasks responsible for one tool or system area.</dd></div>
  <div><dt>Homebrew</dt><dd>A package manager used here to install command-line tools and macOS applications.</dd></div>
</dl>
</div>
</dialog>
</section>

<section class="home-overview" markdown>
<div class="home-overview__summary" markdown>
## What it builds

The result is an opinionated terminal-first environment built around fish,
tmux, Alacritty, Neovim, mise, Git tools, and a curated set of command-line
utilities. On macOS, it also installs desktop applications and applies personal
system defaults.
</div>

<aside class="home-caution" markdown>
### Before you run it

This is a personal configuration. The playbook changes the login shell,
applies dotfiles with `--force`, and modifies macOS preferences.

[Review the setup guide first →](setup.md)
</aside>
</section>

## How the pieces fit together

<ol class="install-flow">
  <li>
    <span>01</span>
    <div>
      <strong>Bootstrap</strong>
      <p>The POSIX <a class="repo-path" href="https://github.com/shmileee/dotfiles/blob/master/scripts/setup.sh"><code>scripts/setup.sh</code></a> validates the platform and starts a disposable, repository-locked Ansible controller.</p>
    </div>
  </li>
  <li>
    <span>02</span>
    <div>
      <strong>Establish workstation state</strong>
      <p>Ansible installs Ubuntu prerequisites, creates the persistent repository checkout, and installs Homebrew on both supported targets.</p>
    </div>
  </li>
  <li>
    <span>03</span>
    <div>
      <strong>Configure the workstation</strong>
      <p>Focused roles install packages and applications, apply dotfiles, and configure fish, mise, Neovim, Rancher Desktop, tmux, and system defaults.</p>
    </div>
  </li>
  <li>
    <span>04</span>
    <div>
      <strong>Hand off to reconciliation</strong>
      <p>The final role validates the persistent locked runtime and records completion; later workstation management uses <code>mise run reconcile</code>.</p>
    </div>
  </li>
</ol>

<aside class="home-validation">
  <strong>Continuously tested</strong>
  <p>The setup is tested on Apple Silicon macOS and in an Ubuntu 24.04 ARM64 container. The container exercises the shared Linux path; macOS applications and system preferences are validated on macOS.</p>
</aside>

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
    <p>Look up bindings for macOS, Alacritty, fish, tmux, and Neovim.</p>
  </a>
  <a href="/opencode/">
    <span>03 · AI tooling</span>
    <strong>Configure OpenCode + OmO</strong>
    <p>Set up local secrets, corporate overlays, model routing, and contextual notifications.</p>
  </a>
</div>

## Design principles

<dl class="principle-grid">
  <div><dt>Repeatable over clever</dt><dd>Repeated runs should converge on the same state.</dd></div>
  <div><dt>Visible over magical</dt><dd>Package lists, roles, and managed files stay in the repository.</dd></div>
  <div><dt>Portable where practical</dt><dd>Shared behavior works on macOS and the Ubuntu integration environment; platform-specific changes stay explicit.</dd></div>
  <div><dt>Personal by design</dt><dd>This is a working environment, not a universal starter kit.</dd></div>
</dl>
