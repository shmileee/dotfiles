-- Default: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

-- Ctrl-S belongs to tmux (copy-mode trigger); drop LazyVim's save-file mapping
-- so the terminal-level shadowing is explicit rather than accidental.
vim.keymap.del({ "i", "x", "n", "s" }, "<C-s>")

map({ "n" }, "o", "o<Esc>")
map({ "n" }, "O", "O<Esc>")

map({ "n" }, "<leader><leader>", "<cmd>nohlsearch<cr>")

-- comment via native gc (0.10+) + ts-comments.nvim; replaces mini.comment
map("n", "<leader>/", "gcc", { remap = true, desc = "Comment line" })
map("x", "<leader>/", "gc", { remap = true, desc = "Comment selection" })

-- https://github.com/LazyVim/LazyVim/discussions/1239
map({ "v" }, ">", ">")
map({ "v" }, "<", "<")
