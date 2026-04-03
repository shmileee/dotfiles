return {
  -- disable "bad" defaults:
  { "folke/flash.nvim", enabled = false },
  { "copilot.lua", enabled = false },
  { "mfussenegger/nvim-lint", enabled = false },
  {
    "ibhagwan/fzf-lua",
    event = "VimEnter",
    keys = { { "<leader><space>", false } },
  },
  {
    "nvim-mini/mini.move",
    opts = {
      mappings = {
        left = "<S-h>",
        right = "<S-l>",
        down = "<S-j>",
        up = "<S-k>",
      },
    },
  },
  {
    "nvim-mini/mini.surround",
    opts = {
      mappings = {
        add = "ys",
        delete = "ds",
        replace = "cs",
      },
    },
  },
  -- customize defaults:
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- prevent ls spam in huge monorepos
        terraformls = { cmd = { "terraform-ls", "serve", "-log-file", "/dev/null" } },
      },
    },
  },
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        ["<C-j>"] = { "select_next" },
        ["<C-k>"] = { "select_prev" },
      },
    },
  },
  {
    "nvim-mini/mini.comment",
    event = "VeryLazy",
    opts = {
      mappings = {
        comment = "<leader>/",
        comment_line = "<leader>/",
        comment_visual = "<leader>/",
      },
    },
  },
  {
    -- custom formatter for terramate
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        terramate = { "terramate" },
      },
      formatters = {
        -- # Example of using shfmt with extra args
        shfmt = {
          prepend_args = { "-i", "2", "-ci", "-sr" },
        },
        terramate = {
          command = "terramate",
          args = { "fmt", "$FILENAME" },
          stdin = false,
          exit_codes = { 0 },
        },
      },
    },
  },
  -- custom plugins:
  { "tpope/vim-repeat" },
  { "terramate-io/vim-terramate" },
  { "christoomey/vim-titlecase" },
  {
    "ntpeters/vim-better-whitespace",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      vim.g.strip_whitespace_on_save = 1
      vim.g.better_whitespace_filetypes_blacklist = {
        "lazy",
        "diff",
        "git",
        "gitcommit",
        "help",
        "snacks_dashboard",
      }
    end,
  },
  {
    "will133/vim-dirdiff",
    cmd = "DirDiff",
    config = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "dirdiff",
        callback = function()
          vim.bo.filetype = "diff"
        end,
      })
    end,
  },
  {
    "chrisgrieser/nvim-spider",
    keys = {
      {
        "w",
        "<cmd>lua require('spider').motion('w')<CR>",
        mode = { "n", "o", "x" },
      },
      {
        "b",
        "<cmd>lua require('spider').motion('b')<CR>",
        mode = { "n", "o", "x" },
      },
    },
  },
  {
    "nmac427/guess-indent.nvim",
    opts = {
      auto_cmd = true,
    },
  },
}
