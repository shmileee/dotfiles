-- Default: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

vim.g.snacks_animate = false

-- ~/.config/git/personal is a gitconfig include; no builtin pattern matches
-- an extensionless name other than "config"
vim.filetype.add({
  pattern = {
    [".*/git/personal"] = "gitconfig",
  },
})
