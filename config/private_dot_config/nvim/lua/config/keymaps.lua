-- Default: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

map({ "n" }, "o", "o<Esc>")
map({ "n" }, "O", "O<Esc>")

map({ "n" }, "<leader><leader>", "<cmd>nohlsearch<cr>")

-- https://github.com/LazyVim/LazyVim/discussions/1239
map({ "v" }, ">", ">")
map({ "v" }, "<", "<")
