local conf = require("telescope.config").values
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local pickers = require("telescope.pickers")

local M = {}

--- The rg command for a prompt: "pattern  glob", split on two spaces. nil for an empty prompt.
--- Shared by the Telescope picker and the controlk source, so both give the same rows.
---@param prompt string|nil
---@return string[]|nil
function M.args(prompt)
  if not prompt or prompt == "" then
    return nil
  end

  local pieces = vim.split(prompt, "  ")
  local args = { "rg" }
  if pieces[1] then
    table.insert(args, "-e")
    table.insert(args, pieces[1])
  end

  if pieces[2] then
    table.insert(args, "-g")
    table.insert(args, pieces[2])
  end

  vim.list_extend(args, {
    "--color=never",
    "--no-heading",
    "--with-filename",
    "--line-number",
    "--column",
    "--smart-case",
  })
  return args
end

local live_multigrep = function(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or vim.uv.cwd()

  local finder = finders.new_async_job({
    command_generator = M.args,
    entry_maker = make_entry.gen_from_vimgrep(opts),
    cwd = opts.cwd,
  })

  pickers
    .new(opts, {
      -- debounce = 100,
      prompt_title = "Multi Grep",
      finder = finder,
      previewer = conf.grep_previewer(opts),
      sorter = require("telescope.sorters").empty(),
    })
    :find()
end

-- The rg run for the previous keystroke, killed when a newer query starts.
local running = nil

--- The same search as a controlk source: `g pattern  *.lua` in the locator.
M.source = {
  prefix = "g",
  title = "Multi grep",
  tag = "grep",
  items = function(query, _, done)
    if running then
      running:kill("sigterm")
      running = nil
    end
    local args = M.args(query)
    if not args then
      return done({})
    end
    local cwd = vim.uv.cwd()
    local handle
    handle = vim.system(args, { cwd = cwd, text = true }, function(result)
      local list = {}
      -- A killed run belongs to an older query: its rows are not wanted.
      if result.signal == 0 then
        for line in (result.stdout or ""):gmatch("[^\n]+") do
          local file, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
          if file then
            table.insert(list, {
              text = vim.trim(text),
              detail = ("%s:%s"):format(file, lnum),
              path = vim.fs.joinpath(cwd, file),
              lnum = tonumber(lnum),
              col = tonumber(col),
              -- rg already filtered them; fuzzy matching must keep every row.
              passthrough = true,
            })
          end
        end
      end
      -- vim.system calls back in a fast event; controlk wants done on the main loop.
      vim.schedule(function()
        if running == handle then
          running = nil
        end
        done(list)
      end)
    end)
    running = handle
  end,
}

M.setup = function()
  vim.keymap.set("n", "<leader>mg", live_multigrep, { desc = "Telescope: [M]ulti [G]rep" })
end

return M
