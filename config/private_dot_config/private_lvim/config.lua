-- general
lvim.log.level = "warn"
lvim.format_on_save = true
lvim.colorscheme = "onedarker"

-- keymappings [view all the defaults by pressing <leader>Lk]
lvim.leader = "space"

-- better putting
lvim.keys.visual_mode["p"] = "pgvy"

lvim.keys.normal_mode["k"] = "gk"
lvim.keys.normal_mode["j"] = "gj"

-- better yanking
lvim.keys.normal_mode["Y"] = "y$"
lvim.keys.visual_mode["y"] = "ygv<esc>"

-- add your own keymapping
lvim.keys.normal_mode["<C-p>"] = "<cmd>lua require('telescope.builtin').find_files({cwd = require('telescope.utils').buffer_dir()})<CR>"
lvim.keys.normal_mode["<Space><Space>"] = "<cmd>nohlsearch<CR>"
lvim.keys.normal_mode["o"] = "o<Esc>"
lvim.keys.normal_mode["O"] = "O<Esc>"

-- Change Telescope navigation to use j and k for navigation and n and p for
-- history in both input and normal mode. we use protected-mode (pcall) just in
-- case the plugin wasn't loaded yet.
local _, actions = pcall(require, "telescope.actions")
lvim.builtin.telescope.defaults.mappings = {
  -- for input mode
  i = {
    ["<C-j>"] = actions.move_selection_next,
    ["<C-k>"] = actions.move_selection_previous,
    ["<C-n>"] = actions.cycle_history_next,
    ["<C-p>"] = actions.cycle_history_prev,
  },
  -- for normal mode
  n = {
    ["<C-j>"] = actions.move_selection_next,
    ["<C-k>"] = actions.move_selection_previous,
  },
}

-- Use which-key to add extra bindings with the leader-key prefix
lvim.builtin.which_key.mappings["P"] = { "<cmd>Telescope projects<CR>", "Projects" }
lvim.builtin.which_key.mappings["n"] = { "<cmd>normal! mz[s1z=`z<CR>", "Fix spelling" }
lvim.builtin.which_key.mappings["f"] = { "<cmd>NvimTreeToggle<CR>", "Explorer" }
lvim.builtin.which_key.mappings["r"] = { ":%s///g<Left><Left>", "Replace" }
lvim.builtin.which_key.mappings["e"] = {}
lvim.builtin.which_key.mappings["q"] = {}
lvim.builtin.which_key.mappings["h"] = {}
lvim.builtin.which_key.mappings["t"] = {
  name = "+Trouble",
  r = { "<cmd>Trouble lsp_references<cr>", "References" },
  f = { "<cmd>Trouble lsp_definitions<cr>", "Definitions" },
  d = { "<cmd>Trouble lsp_document_diagnostics<cr>", "Diagnostics" },
  q = { "<cmd>Trouble quickfix<cr>", "QuickFix" },
  l = { "<cmd>Trouble loclist<cr>", "LocationList" },
  w = { "<cmd>Trouble lsp_workspace_diagnostics<cr>", "Diagnostics" },
}
lvim.builtin.which_key.mappings["st"] = {
  "<cmd>lua require('telescope.builtin').live_grep({cwd = require('telescope.utils').buffer_dir()})<CR>",
  "Search text in current directory"
}

lvim.builtin.alpha.active = true
lvim.builtin.notify.active = true
lvim.builtin.terminal.active = true
lvim.builtin.nvimtree.setup.view.side = "left"
-- lvim.builtin.nvimtree.show_icons.git = 0

lvim.builtin.treesitter.ensure_installed = {
  "bash",
  "hcl",
  "c",
  "javascript",
  "json",
  "make",
  "markdown",
  "lua",
  "python",
  "typescript",
  "css",
  "rust",
  "java",
  "yaml",
}

lvim.builtin.treesitter.ignore_install = { "haskell" }
lvim.builtin.treesitter.highlight.enabled = true

-- generic LSP settings
lvim.lsp.automatic_servers_installation = false

require("lvim.lsp.manager").setup("dockerls", {
  settings = {
    docker = {
      languageserver = {
        formatter = {
          ignoreMultilineInstructions = true,
        },
      },
    },
  },
})

local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup {
  { exe = "black", filetypes = { "python" } },
  { exe = "isort", filetypes = { "python" } },
  { exe = "terraform_fmt", filetypes = { "terraform" } },
  {
    exe = "prettier",
    args = { "--print-with", "100" },
    filetypes = { "typescript", "typescriptreact" },
  },
}

-- -- set additional linters
local linters = require "lvim.lsp.null-ls.linters"
linters.setup {
  {
    exe = "flake8",
    filetypes = { "python" }
  },
  {
    exe = "shellcheck",
    filetypes = { "sh" },
  },
  {
    exe = "codespell",
  },
}

-- Additional Plugins
lvim.plugins = {
  {
    "folke/trouble.nvim",
    cmd = "TroubleToggle",
  },
  {
    "tpope/vim-surround",
    "tpope/vim-repeat",
    "farmergreg/vim-lastplace",
    "will133/vim-dirdiff"
  },
  {
    "iamcco/markdown-preview.nvim",
    opt = true,
    ft = "markdown",
    run = "cd app && yarn install"
  },
  {
    "ntpeters/vim-better-whitespace",
    config = function()
      vim.g.strip_whitespace_confirm = "0"
      vim.g.strip_whitelines_at_eof = "1"
      vim.g.strip_whitespace_on_save = "1"
    end
  },
}

vim.g.better_whitespace_filetypes_blacklist = {
  "diff",
  "gitcommit",
  "help",
  "dashboard",
  "LspTrouble",
  "TelescopePrompt",
}

-- Autocommands (https://neovim.io/doc/user/autocmd.html)
-- lvim.autocommands.custom_groups = {
--   { "BufRead,BufNewFile", "*.md", "setlocal textwidth=80" },
-- }

local init_custom_options = function()
  local custom_options = {
    relativenumber = true, -- Set relative numbered lines
    colorcolumn = "80",
    shell = "/bin/sh"
  }

  for k, v in pairs(custom_options) do
    vim.opt[k] = v
  end
end

init_custom_options()
