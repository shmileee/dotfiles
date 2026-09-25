-- Default: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

-- Ctrl-S belongs to tmux (copy-mode trigger); drop LazyVim's save-file mapping
-- so the terminal-level shadowing is explicit rather than accidental.
vim.keymap.del({ "i", "x", "n", "s" }, "<C-s>")

map({ "n" }, "o", "o<Esc>")
map({ "n" }, "O", "O<Esc>")

map({ "n" }, "<leader><leader>", "<cmd>nohlsearch<cr>")

-- Move by screen line inside a wrapped paragraph, where a single logical
-- line can be five rows tall and plain j jumps over all of them.
--
-- Guarded on v:count rather than mapped outright: with relativenumber on,
-- the whole point of 8j is to land on the line the gutter says is 8 away,
-- and a bare gj mapping would count screen rows and miss it. No count means
-- the cursor is being nudged, which is when gj is wanted; any count means a
-- jump was aimed at a numbered line, which is when it is not.
map(
  { "n", "x" },
  "j",
  "v:count == 0 ? 'gj' : 'j'",
  { expr = true, silent = true }
)
map(
  { "n", "x" },
  "k",
  "v:count == 0 ? 'gk' : 'k'",
  { expr = true, silent = true }
)

-- comment via native gc (0.10+) + ts-comments.nvim; replaces mini.comment
map("n", "<leader>/", "gcc", { remap = true, desc = "Comment line" })
map("x", "<leader>/", "gc", { remap = true, desc = "Comment selection" })

-- https://github.com/LazyVim/LazyVim/discussions/1239
map({ "v" }, ">", ">")
map({ "v" }, "<", "<")

-- Title case, replacing christoomey/vim-titlecase (last commit 2022-07).
-- Nothing maintained offers a title-case operator: coerce.nvim ships every
-- case except this one, text-case.nvim has been idle since 2024. So the rules
-- live here instead of behind a dependency. Same mappings and same behaviour
-- as the plugin: gz{motion}, gzz for whole lines (counted), gz over a visual
-- selection, ALL CAPS words left alone, minor words kept lowercase.
local titlecase_lower = {}
for _, word in ipairs({
  "a",
  "an",
  "and",
  "as",
  "at",
  "but",
  "by",
  "en",
  "for",
  "if",
  "in",
  "nor",
  "of",
  "on",
  "or",
  "per",
  "the",
  "to",
  "v",
  "v.",
  "via",
  "vs",
  "vs.",
}) do
  titlecase_lower[word] = true
end

local function titlecase_word(word)
  -- leave intentional all caps alone (API, HTTP, ...)
  if word == vim.fn.toupper(word) then
    return word
  end
  local lower = vim.fn.tolower(word)
  if titlecase_lower[lower] then
    return lower
  end
  -- strcharpart, not sub, so a leading multibyte character survives
  return vim.fn.toupper(vim.fn.strcharpart(lower, 0, 1))
    .. vim.fn.strcharpart(lower, 1)
end

-- mirrors the plugin's \<\(\k\)\(\k*''*\k*\)\>: starts on a keyword character
-- so a leading quote is excluded, but keeps "don't" as one word. \128-\255
-- covers utf-8 so accented words are not split apart.
local TITLECASE_WORD = "[%w_\128-\255][%w_'\128-\255]*"

local function titlecase_text(text)
  local out = text:gsub(TITLECASE_WORD, titlecase_word)
  return out
end

local function titlecase_capitalize(word)
  if word == vim.fn.toupper(word) then
    return word
  end
  return vim.fn.toupper(vim.fn.strcharpart(word, 0, 1))
    .. vim.fn.strcharpart(word, 1)
end

-- Line-wise title casing always capitalizes the first and last word of each
-- line, even when they are minor words: "the quick fox" -> "The Quick Fox".
-- The plugin did this with two extra :s commands. Unlike the plugin, ALL CAPS
-- words survive here too -- its \u\1\L\2 replacement turned a leading "API"
-- into "Api", which the all-caps guard elsewhere shows was never intended.
local function titlecase_line(line)
  local out = titlecase_text(line)
  out = out:gsub("^(%W*)(" .. TITLECASE_WORD .. ")", function(pre, word)
    return pre .. titlecase_capitalize(word)
  end, 1)
  out = out:gsub("(" .. TITLECASE_WORD .. ")(%W*)$", function(word, post)
    return titlecase_capitalize(word) .. post
  end)
  return out
end

-- 'operatorfunc' takes a function name, so this has to be reachable from
-- vimscript via v:lua
function _G.__titlecase_operator(kind)
  local from, to = "[", "]"
  if kind == "visual" then
    from, to, kind = "<", ">", vim.fn.visualmode()
  end
  local start_mark = vim.api.nvim_buf_get_mark(0, from)
  local end_mark = vim.api.nvim_buf_get_mark(0, to)
  local srow, scol = start_mark[1] - 1, start_mark[2]
  local erow, ecol = end_mark[1] - 1, end_mark[2]

  local function line_at(row)
    return vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
  end

  if kind == "line" or kind == "V" then
    local lines = vim.api.nvim_buf_get_lines(0, srow, erow + 1, false)
    for i, line in ipairs(lines) do
      lines[i] = titlecase_line(line)
    end
    vim.api.nvim_buf_set_lines(0, srow, erow + 1, false, lines)
  elseif kind == "block" or kind == "\22" then
    for row = srow, erow do
      local line = line_at(row)
      local from_col = math.min(scol, #line)
      local to_col = math.min(ecol + 1, #line)
      if to_col > from_col then
        local new = titlecase_text(line:sub(from_col + 1, to_col))
        vim.api.nvim_buf_set_text(0, row, from_col, row, to_col, { new })
      end
    end
  else
    local to_col = math.min(ecol + 1, #line_at(erow))
    local chunk = vim.api.nvim_buf_get_text(0, srow, scol, erow, to_col, {})
    for i, line in ipairs(chunk) do
      chunk[i] = titlecase_text(line)
    end
    vim.api.nvim_buf_set_text(0, srow, scol, erow, to_col, chunk)
  end
end

map("n", "gz", function()
  vim.o.operatorfunc = "v:lua.__titlecase_operator"
  return "g@"
end, { expr = true, desc = "Title case" })

map("n", "gzz", function()
  vim.o.operatorfunc = "v:lua.__titlecase_operator"
  return vim.v.count1 .. "g@_"
end, { expr = true, desc = "Title case line" })

map(
  "x",
  "gz",
  ":<C-u>lua _G.__titlecase_operator('visual')<CR>",
  { silent = true, desc = "Title case" }
)
