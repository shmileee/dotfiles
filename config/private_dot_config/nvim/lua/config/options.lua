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
