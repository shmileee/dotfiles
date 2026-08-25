local packages = {
  "black",
  "hadolint@v2.12.0",
  "markdown-toc",
  "markdownlint-cli2",
  "shellcheck",
  "shfmt",
  "stylua",
  "tflint",
  "tree-sitter-cli",
}

local languages = {
  "bash",
  "c",
  "diff",
  "dockerfile",
  "dtd",
  "fish",
  "git_config",
  "hcl",
  "helm",
  "html",
  "javascript",
  "jsdoc",
  "json",
  "json5",
  "lua",
  "luadoc",
  "luap",
  "markdown",
  "markdown_inline",
  "ninja",
  "printf",
  "python",
  "query",
  "regex",
  "rst",
  "terraform",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "xml",
  "yaml",
}

local treesitter_commit = "7caec274fd19c12b55902a5b795100d21531391f"

local function assert_plugins_installed()
  for name, plugin in pairs(require("lazy.core.config").plugins) do
    if plugin.enabled ~= false and plugin.dir and vim.fn.isdirectory(plugin.dir) == 0 then
      error("plugin was not installed: " .. name)
    end
  end
end

local function install_plugins()
  local lockfile = require("lazy.core.config").options.lockfile
  local file = assert(io.open(lockfile, "rb"))
  local original = file:read("*a")
  file:close()

  local ok, err = xpcall(function()
    require("lazy").install({ wait = true, lockfile = true })
    assert_plugins_installed()
  end, debug.traceback)

  file = assert(io.open(lockfile, "wb"))
  assert(file:write(original))
  assert(file:close())
  assert(ok, err)
end

local function restore_plugins()
  require("lazy").restore({ wait = true })
  assert_plugins_installed()
end

local function install_mason_packages()
  require("lazy").load({ plugins = { "mason.nvim" } })
  local async = require("mason-core.async")
  local Package = require("mason-core.package")
  local registry = require("mason-registry")

  registry.refresh()
  async.run_blocking(function()
    local installers = {}
    for _, specifier in ipairs(packages) do
      local name, version = Package.Parse(specifier)
      local package = registry.get_package(name)
      installers[#installers + 1] = function()
        if package:is_installed() then
          return { success = true, name = name }
        end
        return async.wait(function(resolve)
          package:install({ version = version }, function(success, err)
            resolve({ success = success, name = name, err = err })
          end)
        end)
      end
    end

    local results = { async.wait_all(installers) }
    for _, result in ipairs(results) do
      assert(result.success, ("Mason package %s failed: %s"):format(result.name, tostring(result.err)))
    end
  end)
end

local function install_treesitter_parsers()
  require("lazy").load({ plugins = { "nvim-treesitter" } })
  local plugin = assert(require("lazy.core.config").plugins["nvim-treesitter"])
  local head = vim.trim(vim.fn.system({ "git", "-C", plugin.dir, "rev-parse", "HEAD" }))
  assert(vim.v.shell_error == 0, "could not read nvim-treesitter revision")
  assert(head == treesitter_commit, "unexpected nvim-treesitter revision: " .. head)
  local treesitter = require("nvim-treesitter")
  assert(treesitter.install(languages, { summary = true }):wait(300000), "parser installation failed")
  local installed = treesitter.get_installed("parsers")
  for _, language in ipairs(languages) do
    assert(vim.tbl_contains(installed, language), "parser was not installed: " .. language)
  end
end

local phases = {
  install = install_plugins,
  mason = install_mason_packages,
  restore = restore_plugins,
  treesitter = install_treesitter_parsers,
}

local ok, err = xpcall(function()
  local phase = assert(vim.env.NVIM_BOOTSTRAP_PHASE, "NVIM_BOOTSTRAP_PHASE is required")
  assert(phases[phase], "unknown bootstrap phase: " .. phase)()
end, debug.traceback)

if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
end

vim.cmd("qa")
