-- Default: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

vim.g.snacks_animate = false

-- Only let prettier format where a prettier config exists. Otherwise its
-- defaults fight whichever formatter actually owns the filetype -- biome for
-- css/js/json, rumdl for markdown -- and it mangles the jinja partials in
-- docs/overrides, which nothing else would catch.
vim.g.lazyvim_prettier_needs_config = true

vim.filetype.add({
  extension = {
    -- terramate-io/vim-terramate used to own these. without it nvim resolves
    -- .tm to tcl, and .tfbackend/.tfstate to nothing at all.
    tm = "terramate",
    tfbackend = "hcl",
    tfstate = "json",
    -- nvim's builtin detection only knows *.jinja, so every ansible template
    -- opened as plain text: no highlighting, no comments, no formatter. the
    -- jinja parsers come from plugins/custom.lua.
    j2 = "jinja",
  },
  pattern = {
    -- ~/.config/git/personal is a gitconfig include; no builtin pattern
    -- matches an extensionless name other than "config"
    [".*/git/personal"] = "gitconfig",
    -- builtin detection lands this one on hcl, which would silently drop the
    -- terramate formatter and language server
    [".*%.tm%.hcl"] = "terramate",
  },
})

-- replaces will133/vim-dirdiff, unmaintained since 2021. nvim ships a
-- recursive directory diff with rename detection, but as an opt package, so
-- :DiffTool {left} {right} only exists once it is added. it just registers
-- the command plus a VimEnter hook for `nvim -d dir1 dir2`, so the cost of
-- doing it eagerly is nil.
vim.cmd.packadd("nvim.difftool")

-- there is no terramate treesitter parser: terramate is hcl with extra block
-- types, so point the filetype at the hcl parser that lang.terraform already
-- installs. this is what keeps highlighting after dropping vim-terramate.
vim.treesitter.language.register("hcl", "terramate")

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

-- Soft wrap needs three things and LazyVim only ships one of them. It sets
-- linebreak globally (so a wrap lands between words), leaves wrap off, and
-- never sets breakindent -- which means a wrapped paragraph restarts at
-- column 0 and a continuation is indistinguishable from a new line. The wrap
-- itself is per-filetype and lives in autocmds.lua; these two are inert while
-- wrap is off, so they are safe to set globally.
vim.opt.breakindent = true
vim.opt.showbreak = "↳ "

-- Without this, a .tex file with no \documentclass in it is plain TeX: nvim's
-- detection falls back to g:tex_flavor, which defaults to "plain". This repo
-- splits a LaTeX document across fragments, so src/content/summary.tex and
-- src/sidebars/page1.tex came out as plaintex while cv.tex and
-- experience-part1.tex -- which do contain \begin{} -- came out as tex. Two
-- filetypes over one document meant two sets of syntax rules and, because
-- LazyVim's wrap list contains plaintex but not tex, wrapping that worked in
-- half the files and not the other half.
vim.g.tex_flavor = "latex"
