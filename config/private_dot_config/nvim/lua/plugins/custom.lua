local plugins = {
  -- disabled defaults:
  { "folke/flash.nvim", enabled = false },
  { "zbirenbaum/copilot.lua", enabled = false },
  { "CopilotC-Nvim/CopilotChat.nvim", enabled = false },
  { "mfussenegger/nvim-lint", enabled = false },
  -- superseded by wallpants/github-preview.nvim below: upstream master has
  -- not moved since 2023-10 and its single-buffer server cannot resolve
  -- relative links to other local markdown files
  { "iamcco/markdown-preview.nvim", enabled = false },
  {
    "ibhagwan/fzf-lua",
    keys = {
      -- both conflict with custom keymaps (keymaps.lua):
      -- <leader><leader> -> nohlsearch, <leader>/ -> comment
      { "<leader><space>", false },
      { "<leader>/", false },
    },
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
    -- LazyVim already defaults to moon; pinned so the style stays explicit
    -- and in sync with the terminal stack (alacritty/tmux/fzf/lazygit/bat).
    "folke/tokyonight.nvim",
    opts = { style = "moon" },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- prevent ls spam in huge monorepos
        terraformls = {
          cmd = { "terraform-ls", "serve", "-log-file", "/dev/null" },
        },
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
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        terramate = { "terramate" },
      },
      formatters = {
        shfmt = {
          prepend_args = { "-i", "2", "-bn", "-ci", "-sr" },
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
  {
    -- chezmoi source files: resolve target filetype (dot_*, private_*, *.tmpl)
    -- and layer go-template highlighting on top
    "alker0/chezmoi.vim",
    lazy = false,
    init = function()
      -- required with lazy.nvim: avoids plugin load-order constraints
      vim.g["chezmoi#use_tmp_buffer"] = 1
      -- source dir is non-default (ghq repo + .chezmoiroot), so resolve it
      -- via `chezmoi source-path` instead of hardcoding
      vim.g["chezmoi#use_external"] = 1
      -- treesitter can't parse compound "<ft>.chezmoitmpl" filetypes and
      -- suppresses regex syntax when attached (plugin FAQ #3): stop it and
      -- force regex syntax so the go-template overlay actually renders
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "*.chezmoitmpl",
        group = vim.api.nvim_create_augroup(
          "chezmoi_tmpl_syntax",
          { clear = true }
        ),
        callback = function(ev)
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(ev.buf) then
              vim.treesitter.stop(ev.buf)
              vim.bo[ev.buf].syntax = ev.match
            end
          end)
        end,
      })
    end,
  },
  { "terramate-io/vim-terramate", ft = "terramate" },
  {
    "ntpeters/vim-better-whitespace",
    event = { "BufReadPost", "BufNewFile" },
    init = function()
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
    init = function()
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
  {
    -- browser preview replacing LazyVim's markdown-preview.nvim. repository
    -- mode (entered whenever a .git dir is found) serves the whole repo, so
    -- relative links to other markdown files are clickable and browsable the
    -- way they are on github.com. needs bun, pinned in mise/config.toml
    "wallpants/github-preview.nvim",
    cmd = {
      "GithubPreviewToggle",
      "GithubPreviewStart",
      "GithubPreviewStop",
    },
    keys = {
      -- the key LazyVim's markdown extra bound to MarkdownPreviewToggle
      {
        "<leader>cp",
        "<cmd>GithubPreviewToggle<cr>",
        ft = "markdown",
        desc = "Markdown Preview",
      },
    },
    opts = {
      -- default false lets a preview started in one nvim kill the preview of
      -- every other; parallel nvim instances across tmux windows are the norm
      -- here, so let each one claim its own port instead
      allow_multiple_instances = true,
    },
  },
  {
    -- <cr> on a markdown link opens the target in nvim: relative, absolute
    -- and ~ paths, #headings, file.md:42, reference links; urls still go to
    -- the browser. the counterpart to the preview above -- a linked file
    -- lands in an editable buffer rather than a browser tab. the mapping
    -- ships in the plugin's own ftplugin/markdown.lua; there is no setup()
    "jghauser/follow-md-links.nvim",
    ft = "markdown",
  },
}

if vim.env.DOCKERIZED == "true" then
  table.insert(plugins, {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = {}
    end,
  })
  table.insert(plugins, {
    "nvim-treesitter/nvim-treesitter",
    build = false,
    opts = function(_, opts)
      opts.ensure_installed = {}
    end,
  })
end

return plugins
