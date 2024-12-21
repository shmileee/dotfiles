-- Default: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Disable autoformat for Dockerfiles
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "dockerfile" },
  callback = function()
    vim.b.autoformat = false
  end,
})

-- Fix Helm syntax highlighting
vim.api.nvim_create_autocmd({ "BufRead", "BufEnter" }, {
  pattern = "*.yaml",
  callback = function()
    if vim.bo[vim.api.nvim_get_current_buf()].filetype == "helm" then
      vim.cmd("TSToggle highlight")
      vim.cmd("TSToggle highlight")
    end
  end,
})
