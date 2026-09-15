-- Default: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

vim.g.snacks_animate = false

-- Only let prettier format where a prettier config exists. Otherwise its
-- defaults fight whichever formatter actually owns the filetype -- biome for
-- css/js/json, rumdl for markdown -- and it mangles the jinja partials in
-- docs/overrides, which nothing else would catch.
vim.g.lazyvim_prettier_needs_config = true

-- ~/.config/git/personal is a gitconfig include; no builtin pattern matches
-- an extensionless name other than "config"
vim.filetype.add({
  pattern = {
    [".*/git/personal"] = "gitconfig",
  },
})

-- Neovim probes python3, python3.14 ... python3.9, python in order, spawning
-- each to look for the "neovim" module. pynvim is installed nowhere, so the
-- walk never short-circuits and re-runs on every has("python3"). Two
-- candidates make that expensive here: python3.12 resolves to a mise shim
-- (~160ms per spawn) and python resolves to the aws-cli payload, which is a
-- Mach-O *shared library*, so vim.system throws ENOEXEC. Opening a python
-- file cost ~1200ms, of which ~1040ms was this.
--
-- Setting python3_host_prog makes detect_by_module() return on its first
-- branch without spawning anything (~150ms), and points the provider at
-- mise's python, which is the one that should be serving it anyway. The shim
-- rather than a versioned install path, so it survives python upgrades and
-- honours per-directory mise versions.
vim.g.python3_host_prog = vim.fn.expand("~/.local/share/mise/shims/python3")
