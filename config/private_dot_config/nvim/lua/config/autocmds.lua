-- Default: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Disable autoformat for Dockerfiles
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "dockerfile" },
  callback = function()
    vim.b.autoformat = false
  end,
})
