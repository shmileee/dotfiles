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
        -- replaces terramate-io/vim-terramate, unmaintained since 2023. the
        -- language server ships inside the mise-managed terramate cli and is
        -- absent from mason's registry, so LazyVim wires it up natively with
        -- vim.lsp.config + vim.lsp.enable instead of trying to install it.
        terramate_ls = {
          cmd = { "terramate-ls" },
          filetypes = { "terramate" },
          root_markers = { "terramate.tm.hcl", ".git" },
        },
        -- LazyVim's terraform extra only installs the tflint binary; it is
        -- mason-lspconfig's automatic_enable that turns it into a second
        -- language server on every .tf buffer. That server spawns
        -- `tflint --act-as-bundled-plugin`, which it never reaps: each nvim
        -- session that opened a terraform file left one behind for good
        -- (PPID 1, 30-65MB). Nothing else here runs tflint -- no .tflint.hcl,
        -- no pre-commit hook, no CI job -- so it was linting with the default
        -- ruleset only. terraform-ls keeps reporting real errors.
        tflint = { enabled = false },
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
        -- replaces the formatting.black extra: mason's black is a python venv
        -- wrapper whose interpreter mise has since removed, so it fails with
        -- ENOENT on every save while conform still reports it as available --
        -- silently leaving the buffer unformatted. ruff is already installed
        -- for the lang.python extra's language server, formats in ~15ms
        -- instead of black's ~200ms, and is what pre-commit runs here.
        python = { "ruff_format" },
        terramate = { "terramate" },
      },
      formatters = {
        shfmt = {
          prepend_args = { "-i", "2", "-bn", "-ci", "-sr" },
        },
        -- no ruff_format entry: the config it needs has to be discoverable
        -- anyway, because the editor, the ruff language server and a bare
        -- `ruff check` cannot be handed a --config flag.
        terramate = {
          command = "terramate",
          args = { "fmt", "$FILENAME" },
          stdin = false,
          exit_codes = { 0 },
        },
      },
    },
  },
  {
    -- .j2 gets no filetype from nvim (it only knows *.jinja), so ansible
    -- templates open as plain text. these are the parsers for the filetype
    -- mapping added in options.lua; jinja_inline covers the {{ ... }}
    -- expressions injected inside jinja blocks.
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "jinja", "jinja_inline" } },
  },
  {
    -- with the tflint language server off (see nvim-lspconfig above), the
    -- binary LazyVim's terraform extra installs has no consumer left.
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(tool)
        return tool ~= "tflint"
      end, opts.ensure_installed or {})
    end,
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
      -- the source dir is non-default (ghq repo + .chezmoiroot), and letting
      -- the plugin discover it with `chezmoi source-path` cost 58ms of every
      -- single nvim start, in every repo (measured 193ms -> 136ms with the
      -- plugin disabled entirely). The path only moves if this repo does, so
      -- name it: sourceDir from ~/.config/chezmoi/chezmoi.toml plus the
      -- .chezmoiroot below it. Setting this also skips the plugin's own
      -- .chezmoiroot handling, hence the full path. If it ever stops
      -- existing, fall back to asking chezmoi rather than silently losing
      -- filetype detection for every dotfile.
      local source_dir =
        vim.fn.expand("~/ghq/personalgit/shmileee/dotfiles/config")
      if vim.uv.fs_stat(source_dir) then
        vim.g["chezmoi#source_dir_path"] = source_dir
      else
        vim.g["chezmoi#use_external"] = 1
      end
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
  {
    -- replaces ntpeters/vim-better-whitespace. neovim's builtin editorconfig
    -- support already strips trailing whitespace on write wherever a
    -- .editorconfig sets trim_trailing_whitespace, so only the highlight and
    -- the strip-everywhere-else behaviour of strip_whitespace_on_save = 1
    -- still need a plugin.
    "nvim-mini/mini.trailspace",
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
    config = function(_, opts)
      local trailspace = require("mini.trailspace")
      trailspace.setup(opts)

      -- the old better_whitespace_filetypes_blacklist. most of these already
      -- fall out of only_in_normal_buffers, but naming them keeps the set
      -- explicit and covers diff/git/gitcommit, which are real buffers.
      local skip = {
        diff = true,
        git = true,
        gitcommit = true,
        help = true,
        lazy = true,
        snacks_dashboard = true,
      }

      local group =
        vim.api.nvim_create_augroup("trailspace_custom", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        callback = function(ev)
          if skip[vim.bo[ev.buf].filetype] then
            vim.b[ev.buf].minitrailspace_disable = true
          end
        end,
      })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = group,
        callback = function(ev)
          if not skip[vim.bo[ev.buf].filetype] then
            trailspace.trim()
          end
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
