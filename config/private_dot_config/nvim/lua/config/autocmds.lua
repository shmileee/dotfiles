-- Default: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Disable autoformat for Dockerfiles
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "dockerfile" },
  callback = function()
    vim.b.autoformat = false
  end,
})

-- LazyVim wraps text, plaintex, typst, gitcommit and markdown, but not tex.
-- With g:tex_flavor set to latex in options.lua every .tex file is now tex,
-- so without this line the LaTeX sources that used to wrap stopped wrapping.
-- Same settings as LazyVim's wrap_spell group minus the spell check, which
-- on a file this full of macros and slugs is more noise than signal.
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "tex", "latex", "bib" },
  callback = function()
    vim.opt_local.wrap = true
  end,
})

-- gw and gq run neovim's internal formatter, which asks 'indentexpr' for the
-- indent of every line it opens. runtime/indent/tex.vim answers with a
-- shiftwidth per \begin{} nesting level, plus another one for a \item
-- continuation, so rewrapping a bullet pushed its own tail lines rightwards
-- and turned a flush-left paragraph into a staircase. Nothing in a LaTeX
-- source here is indented -- .editorconfig wraps .tex at 80 columns and every
-- line starts at column 0 -- so there is no indent to compute. Clearing it
-- leaves 'autoindent', which copies the previous line's indent and so keeps a
-- wrapped paragraph exactly where it started: what gw already does in
-- markdown. ft=tex is the only one of these with an indentexpr at all;
-- plaintex, latex and bib have none.
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "tex" },
  callback = function()
    vim.bo.indentexpr = ""
  end,
})
