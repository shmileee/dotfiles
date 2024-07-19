-- general
vim.opt.spell = true
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

lvim.log.level = "warn"
lvim.format_on_save = true
lvim.colorscheme = "onedarker"

lvim.leader = "space"

-- add your own keymapping
lvim.keys.normal_mode["<C-p>"] =
"<cmd>lua require('telescope.builtin').find_files({cwd = require('telescope.utils').buffer_dir()})<CR>"
lvim.keys.normal_mode["<Space><Space>"] = "<cmd>nohlsearch<CR>"
lvim.keys.normal_mode["o"] = "o<Esc>"
lvim.keys.normal_mode["O"] = "O<Esc>"
lvim.keys.normal_mode["<S-h>"] = "<cmd>bnext<CR>"
lvim.keys.normal_mode["<S-l>"] = "<cmd>bprev<CR>"
lvim.keys.normal_mode["k"] = "gk"
lvim.keys.normal_mode["j"] = "gj"
lvim.keys.visual_mode["p"] = "pgvy"
lvim.keys.normal_mode["Y"] = "y$"
lvim.keys.visual_mode["y"] = "ygv<esc>"

-- Change Telescope navigation to use j and k for navigation and n and p for history in both input and normal mode.
-- we use protected-mode (pcall) just in case the plugin wasn't loaded yet.
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
lvim.builtin.which_key.mappings["st"] = {
  "<cmd>lua require('telescope.builtin').live_grep({cwd = require('telescope.utils').buffer_dir()})<CR>",
  "Search text in current directory"
}

lvim.builtin.which_key.mappings["n"] = { "<cmd>normal! mz[s1z=`z<CR>", "Fix spelling" }
lvim.builtin.which_key.mappings["r"] = { ":%s///g<Left><Left>", "Replace" }

lvim.builtin.alpha.active = true
lvim.builtin.alpha.mode = "dashboard"
lvim.builtin.terminal.active = true
lvim.builtin.nvimtree.setup.view.side = "left"
lvim.builtin.nvimtree.setup.renderer.icons.show.git = true
lvim.builtin.project.manual_mode = true

-- if you don't want all the parsers change this to a table of the ones you want
lvim.builtin.treesitter.ensure_installed = {
  "bash",
  "c",
  "css",
  "hcl",
  "java",
  "javascript",
  "json",
  "lua",
  "make",
  "markdown",
  "python",
  "rust",
  "tsx",
  "typescript",
  "yaml",
}

lvim.builtin.treesitter.ignore_install = { "haskell" }
lvim.builtin.treesitter.highlight.enabled = true

-- generic LSP settings
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
  { exe = "black",         filetypes = { "python" } },
  { exe = "isort",         filetypes = { "python" } },
  { exe = "terraform_fmt", filetypes = { "terraform" } }
}

local linters = require "lvim.lsp.null-ls.linters"
linters.setup {
  { command = "flake8", filetypes = { "python" } },
  {
    command = "shellcheck",
    extra_args = { "--severity", "warning" },
  },
  {
    command = "codespell"
  },
}

-- Additional Plugins
lvim.plugins = {
  {
    "tpope/vim-surround",
    "tpope/vim-repeat",
    "farmergreg/vim-lastplace",
    "will133/vim-dirdiff"
  },
  {
    "iamcco/markdown-preview.nvim",
    lazy = false,
    ft = "markdown",
  },
  {
    "ntpeters/vim-better-whitespace",
    config = function()
      vim.g.strip_whitespace_confirm = "0"
      vim.g.strip_whitelines_at_eof = "1"
      vim.g.strip_whitespace_on_save = "1"
    end
  },
  {
    "wellle/targets.vim"
  },
  {
    "christoomey/vim-titlecase"
  },
  {
    'mrjones2014/dash.nvim',
    build = 'make install',
  },
  {
    'towolf/vim-helm'
  },
  {
    'terramate-io/vim-terramate'
  }
}

vim.g.better_whitespace_filetypes_blacklist = {
  "diff",
  "gitcommit",
  "help",
  "dashboard",
  "LspTrouble",
  "TelescopePrompt",
}

lvim.lsp.on_attach_callback = function(client, bufnr)
  if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].filetype == "helm" then
    vim.diagnostic.disable()
  end
end

lvim.autocommands = {
  {
    "BufWritePre",
    {
      pattern = { "*.tm", "*.tm.hcl" },
      command = "silent :execute '!terramate fmt' | edit! %",
    }
  },
}
