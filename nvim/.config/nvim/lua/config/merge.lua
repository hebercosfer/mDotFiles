-- Merge conflict helpers.
--
-- These act on the conflict markers in the buffer rather than on diff hunks.
-- Git's nvimdiff layout leaves the markers in the MERGED buffer, and :diffget
-- works per diff hunk, which does not line up with whole conflict blocks -- it
-- strips a single marker line at a time. Parsing the markers resolves a block
-- in one keystroke and works the same whether the file is open in mergetool or
-- edited directly.
--
-- With merge.conflictstyle = diff3 a block looks like:
--   <<<<<<< HEAD        start    ours
--   ||||||| <sha>       base     common ancestor (diff3 only)
--   =======             mid      theirs
--   >>>>>>> <branch>    fin

local M = {}

local function conflicts()
  local out, cur = {}, nil
  for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line:match("^<<<<<<<") then
      cur = { start = i }
    elseif cur and line:match("^|||||||") then
      cur.base = i
    elseif cur and line:match("^=======$") then
      cur.mid = i
    elseif cur and line:match("^>>>>>>>") then
      if cur.mid then
        cur.fin = i
        out[#out + 1] = cur
      end
      cur = nil
    end
  end
  return out
end

-- The block under the cursor, else the next one below it.
local function current_block()
  local line = vim.fn.line(".")
  local found = conflicts()
  for _, b in ipairs(found) do
    if line >= b.start and line <= b.fin then
      return b
    end
  end
  for _, b in ipairs(found) do
    if b.start > line then
      return b
    end
  end
end

function M.take(side)
  local b = current_block()
  if not b then
    vim.notify("Merge: no conflict found", vim.log.levels.WARN)
    return
  end

  local first, last
  if side == "local" then
    first, last = b.start + 1, (b.base or b.mid) - 1
  elseif side == "base" then
    if not b.base then
      vim.notify("Merge: no base section (conflictstyle is not diff3)", vim.log.levels.WARN)
      return
    end
    first, last = b.base + 1, b.mid - 1
  else
    first, last = b.mid + 1, b.fin - 1
  end

  local keep = {}
  if last >= first then
    keep = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  end
  vim.api.nvim_buf_set_lines(0, b.start - 1, b.fin, false, keep)
  vim.api.nvim_win_set_cursor(0, { math.min(b.start, vim.api.nvim_buf_line_count(0)), 0 })
  if vim.o.diff then
    vim.cmd("diffupdate")
  end
end

function M.jump(direction)
  local found = conflicts()
  if #found == 0 then
    vim.notify("Merge: no conflict found", vim.log.levels.WARN)
    return
  end

  local line = vim.fn.line(".")
  local target
  if direction > 0 then
    for _, b in ipairs(found) do
      if b.start > line then
        target = b.start
        break
      end
    end
    target = target or found[1].start
  else
    for i = #found, 1, -1 do
      if found[i].start < line then
        target = found[i].start
        break
      end
    end
    target = target or found[#found].start
  end
  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

local map = function(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { desc = desc })
end

map("<leader>ml", function()
  M.take("local")
end, "[M]erge: take [L]ocal (ours)")
map("<leader>mb", function()
  M.take("base")
end, "[M]erge: take [B]ase (ancestor)")
map("<leader>mr", function()
  M.take("remote")
end, "[M]erge: take [R]emote (theirs)")
map("<leader>mn", function()
  M.jump(1)
end, "[M]erge: [N]ext conflict")
map("<leader>mN", function()
  M.jump(-1)
end, "Merge: previous conflict")

return M