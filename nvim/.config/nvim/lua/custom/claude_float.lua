-- Custom floating-terminal provider for claudecode.nvim.
-- Mirrors the centered/rounded style of custom/floaterminal.lua so Claude Code
-- opens in a floating window instead of a Snacks split.
--
-- Implements the claudecode.nvim terminal provider interface:
--   setup, open, close, simple_toggle, focus_toggle, get_active_bufnr, is_available
--
-- Extra (non-interface) API used by keymaps:
--   minimize()    hide the big float, show a small corner notification
--   restore()     bring the big float back
--   toggle_mini() flip between the float and the corner notification

local M = {}

local uv = vim.uv or vim.loop

local state = {
    buf = -1,
    win = -1,
    jobid = -1,
    -- Minimized "notification" window that tails the latest message.
    mini_buf = -1,
    mini_win = -1,
    mini_timer = nil,
    -- Background watcher that auto-minimizes when an edit-approval diff opens.
    watch_timer = nil,
    diff_seen = false,
}

-- Tuning for the corner notification.
local mini = {
    width = 64,
    max_height = 12,
    refresh_ms = 250,
    -- Trailing output to tail into the notification: the status/spinner line
    -- plus the message paragraph before it.
    max_lines = 12, -- hard cap on lines shown
    gaps = 1, -- blank-line separators to cross before stopping
    -- Auto-minimize the float when an edit-approval diff opens (so the diff,
    -- which the float would otherwise cover, is visible).
    auto_minimize_on_diff = true,
    watch_ms = 300, -- how often to poll for an open diff
}

local function buf_valid()
    return state.buf ~= -1 and vim.api.nvim_buf_is_valid(state.buf)
end

local function win_valid()
    return state.win ~= -1 and vim.api.nvim_win_is_valid(state.win)
end

local function mini_buf_valid()
    return state.mini_buf ~= -1 and vim.api.nvim_buf_is_valid(state.mini_buf)
end

local function mini_win_valid()
    return state.mini_win ~= -1 and vim.api.nvim_win_is_valid(state.mini_win)
end

--- Notification window ------------------------------------------------------

-- Top-left corner glyphs of Claude Code's input prompt box.
local BOX_TOPS = { "╭", "┌" }

local function is_box_top(line)
    local s = line:gsub("^%s+", "")
    for _, c in ipairs(BOX_TOPS) do
        if s:sub(1, #c) == c then
            return true
        end
    end
    return false
end

-- Claude's current input prompt is framed by two full-width horizontal rules
-- (────) rather than a corner box. A rule is a line made entirely of one
-- repeated rule glyph (allowing surrounding whitespace).
local RULE_CHARS = { "─", "━", "═", "—", "-", "_" }

local function is_rule(line)
    local s = line:gsub("%s+", "")
    if s == "" then
        return false
    end
    for _, c in ipairs(RULE_CHARS) do
        if s:gsub(c, "") == "" and #s >= #c * 8 then
            return true
        end
    end
    return false
end

-- Claude's live status/spinner line sits directly above the input box while a
-- task runs, e.g. "✶ Baked for 17s … (esc to interrupt)". When it is the line
-- we anchor on, we also pull in the message paragraph above it; when Claude is
-- idle there is no such line, so we show only the last message paragraph.
local SPINNER_GLYPHS =
    { "·", "✢", "✳", "✶", "✻", "✽", "∗", "*", "✺", "✦", "✷", "✸", "✴" }

local function is_status_line(line)
    if line == nil then
        return false
    end
    local s = line:gsub("^%s+", "")
    if s:find("esc to interrupt", 1, true) then
        return true
    end
    for _, g in ipairs(SPINNER_GLYPHS) do
        if s:sub(1, #g) == g then
            -- A glyph alone is ambiguous (e.g. a markdown bullet), so require a
            -- standalone timer like "17s" to treat it as a status line.
            return s:find("%f[%d]%d+s%f[%W]") ~= nil
        end
    end
    return false
end

-- claudecode.nvim shows an edit approval as a native diff (not a terminal
-- prompt): the proposed side is a scratch buffer (buftype=acwrite) named like
-- "✻ [Claude Code] <file> (<hash>) ⧉ (proposed)" or "… (NEW FILE - proposed)"
-- (claudecode/diff.lua:1209, confirmed via a live capture). Our editor-relative
-- float sits on top of those splits, so the presence of such a buffer is the
-- cue to drop out of the way. The "(New)" names are an older fallback path.
local function diff_pending()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(b) then
            local name = vim.api.nvim_buf_get_name(b)
            if
                name:find("[Claude Code]", 1, true)
                or name:find("proposed)", 1, true)
                or name:match("%(New%)$")
                or name:match("%(NEW FILE%)$")
            then
                return true
            end
        end
    end
    return false
end

-- The current task status: the trailing block of conversation output that sits
-- ABOVE the input prompt box -- the spinner/status line ("✶ Baked for 17s")
-- plus the message paragraph before it. Falls back to a plain tail if no box
-- has been rendered yet.
local function status_lines()
    if not buf_valid() then
        return { "(Claude Code is not running)" }
    end

    local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
    local function blank(i)
        return lines[i] == nil or lines[i]:gsub("%s+$", "") == ""
    end

    -- The input box bounds the bottom; everything above it is the conversation.
    -- The prompt is framed by two full-width rules (────) with the input
    -- between, or (older UI) a ╭rounded╮ box. Anchor the boundary at the box's
    -- TOP edge so the prompt, rules and status bar below never leak in.
    local boundary = #lines + 1
    local bottom_rule
    for i = #lines, 1, -1 do
        if is_rule(lines[i]) then
            bottom_rule = i
            break
        end
    end
    if bottom_rule then
        boundary = bottom_rule
        for i = bottom_rule - 1, math.max(1, bottom_rule - 6), -1 do
            if is_rule(lines[i]) then
                boundary = i
                break
            end
        end
    else
        for i = #lines, 1, -1 do
            if is_box_top(lines[i]) then
                boundary = i
                break
            end
        end
    end

    -- The live status/spinner line (the current task) sits just above the box,
    -- though a "Tip:"/blank footer line may sit between them. Look for it in a
    -- small window; otherwise fall back to the last message line (idle).
    local last
    for i = boundary - 1, math.max(1, boundary - 6), -1 do
        if is_rule(lines[i]) or is_box_top(lines[i]) then
            break
        end
        if is_status_line(lines[i]) then
            last = i
            break
        end
    end
    if not last then
        for i = boundary - 1, 1, -1 do
            if not blank(i) then
                last = i
                break
            end
        end
    end
    if not last then
        return { "(no output yet)" }
    end

    -- When anchored on the live status line, reach across up to `mini.gaps`
    -- blank separators to also grab the message paragraph above it. When idle
    -- (anchored on a message), stop at the first blank so we show only the last
    -- paragraph and never spill into the previous turn.
    local max_gaps = is_status_line(lines[last]) and mini.gaps or 0
    local first, gaps = last, 0
    for i = last - 1, 1, -1 do
        if is_rule(lines[i]) or is_box_top(lines[i]) or (last - i + 1) > mini.max_lines then
            break
        end
        if blank(i) then
            gaps = gaps + 1
            if gaps > max_gaps then
                break
            end
        end
        first = i
    end

    local out = {}
    for i = first, last do
        table.insert(out, (lines[i]:gsub("%s+$", "")))
    end
    while out[1] == "" do
        table.remove(out, 1)
    end
    while out[#out] == "" do
        table.remove(out)
    end
    if #out == 0 then
        out = { "(no output yet)" }
    end
    return out
end

local function stop_mini_timer()
    if state.mini_timer then
        state.mini_timer:stop()
        if not state.mini_timer:is_closing() then
            state.mini_timer:close()
        end
        state.mini_timer = nil
    end
end

local function hide_mini()
    stop_mini_timer()
    if mini_win_valid() then
        vim.api.nvim_win_close(state.mini_win, true)
    end
    state.mini_win = -1
end

-- Render (creating or resizing) the corner notification.
local function render_mini()
    local content = status_lines()

    if not mini_buf_valid() then
        state.mini_buf = vim.api.nvim_create_buf(false, true)
    end
    vim.bo[state.mini_buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.mini_buf, 0, -1, false, content)
    vim.bo[state.mini_buf].modifiable = false

    local width = math.min(mini.width, vim.o.columns - 4)

    -- Height has to account for lines that wrap at `width`.
    local rows = 0
    for _, line in ipairs(content) do
        rows = rows + math.max(1, math.ceil(vim.fn.strdisplaywidth(line) / width))
    end
    local height = math.max(1, math.min(mini.max_height, rows))

    local col = math.max(1, vim.o.columns - width - 2)
    local row = math.max(1, vim.o.lines - height - 3)

    local cfg = {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",
        border = "rounded",
        title = " Claude ",
        title_pos = "center",
        focusable = false,
        zindex = 60,
    }

    if mini_win_valid() then
        vim.api.nvim_win_set_config(state.mini_win, cfg)
    else
        state.mini_win = vim.api.nvim_open_win(state.mini_buf, false, cfg)
        vim.wo[state.mini_win].wrap = true
    end

    -- Keep the newest line (status/spinner) in view if the block overflows.
    pcall(vim.api.nvim_win_set_cursor, state.mini_win, { #content, 0 })
end

local function show_mini()
    if not buf_valid() then
        vim.notify("Claude Code is not running.", vim.log.levels.WARN)
        return false
    end
    render_mini()
    stop_mini_timer()
    state.mini_timer = uv.new_timer()
    state.mini_timer:start(
        mini.refresh_ms,
        mini.refresh_ms,
        vim.schedule_wrap(function()
            if not mini_win_valid() then
                stop_mini_timer()
                return
            end
            if not buf_valid() then
                hide_mini()
                return
            end
            render_mini()
        end)
    )
    return true
end

local function stop_watch()
    if state.watch_timer then
        state.watch_timer:stop()
        if not state.watch_timer:is_closing() then
            state.watch_timer:close()
        end
        state.watch_timer = nil
    end
    state.diff_seen = false
end

-- Poll while the full float is open and collapse it to the corner notification
-- the moment an edit-approval diff appears. Edge-triggered: it fires once per
-- diff and re-arms only after the diff clears, so a manual restore (to review
-- the diff) is never fought.
local function start_watch()
    stop_watch()
    if not mini.auto_minimize_on_diff then
        return
    end
    state.watch_timer = uv.new_timer()
    state.watch_timer:start(
        mini.watch_ms,
        mini.watch_ms,
        vim.schedule_wrap(function()
            if not buf_valid() then
                stop_watch()
                return
            end
            -- Only act while the big float is showing; ignore when minimized.
            if not win_valid() then
                return
            end
            if diff_pending() then
                if not state.diff_seen then
                    state.diff_seen = true
                    M.minimize()
                end
            else
                state.diff_seen = false
            end
        end)
    )
end

--- Big float ----------------------------------------------------------------

local function open_window()
    -- Bringing the full float back always dismisses the notification.
    hide_mini()

    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf
    if buf_valid() then
        buf = state.buf
    else
        buf = vim.api.nvim_create_buf(false, true)
    end

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",
        border = "rounded",
        title = " Claude Code ",
        title_pos = "center",
    })

    state.buf = buf
    state.win = win
    return buf, win
end

local function hide_window()
    if win_valid() then
        vim.api.nvim_win_hide(state.win)
    end
    state.win = -1
end

local function focus_window()
    if win_valid() then
        vim.api.nvim_set_current_win(state.win)
        vim.cmd("startinsert")
    end
end

local function spawn(cmd_string, env_table, effective_config, focus)
    local original_win = vim.api.nvim_get_current_win()
    open_window()

    local cmd_arg
    if cmd_string:find(" ", 1, true) then
        cmd_arg = vim.split(cmd_string, " ", { plain = true, trimempty = false })
    else
        cmd_arg = { cmd_string }
    end

    state.jobid = vim.fn.termopen(cmd_arg, {
        env = env_table,
        cwd = effective_config and effective_config.cwd or nil,
        on_exit = function(job_id)
            vim.schedule(function()
                if job_id ~= state.jobid then
                    return
                end
                stop_watch()
                hide_mini()
                if
                    win_valid() and (not effective_config or effective_config.auto_close ~= false)
                then
                    vim.api.nvim_win_close(state.win, true)
                end
                if buf_valid() then
                    vim.api.nvim_buf_delete(state.buf, { force = true })
                end
                state.buf = -1
                state.win = -1
                state.jobid = -1
            end)
        end,
    })

    if not state.jobid or state.jobid <= 0 then
        vim.notify("Failed to open Claude floating terminal.", vim.log.levels.ERROR)
        if win_valid() then
            vim.api.nvim_win_close(state.win, true)
        end
        state.buf, state.win, state.jobid = -1, -1, -1
        return false
    end

    vim.bo[state.buf].bufhidden = "hide"

    -- Minimize straight from the terminal without leaving insert mode.
    -- Chord avoids Alt (swallowed by some terminals) and Claude's own keys.
    vim.keymap.set("t", "<C-x><C-m>", function()
        M.minimize()
    end, { buffer = state.buf, desc = "Minimize Claude to a corner notification" })

    start_watch()

    if focus ~= false then
        focus_window()
    elseif vim.api.nvim_win_is_valid(original_win) then
        vim.api.nvim_set_current_win(original_win)
    end
    return true
end

--- Provider interface -------------------------------------------------------

function M.setup(_term_config)
    -- Style is fixed (centered float); nothing to configure here.
end

function M.open(cmd_string, env_table, effective_config, focus)
    if buf_valid() then
        if not win_valid() then
            -- Process alive but hidden: reattach the buffer to a new float.
            local original_win = vim.api.nvim_get_current_win()
            open_window()
            if focus ~= false then
                focus_window()
            elseif vim.api.nvim_win_is_valid(original_win) then
                vim.api.nvim_set_current_win(original_win)
            end
        elseif focus ~= false then
            focus_window()
        end
    else
        spawn(cmd_string, env_table, effective_config, focus)
    end
end

function M.close()
    stop_watch()
    hide_mini()
    if win_valid() then
        vim.api.nvim_win_close(state.win, true)
    end
    if state.jobid and state.jobid > 0 then
        vim.fn.jobstop(state.jobid)
    end
    state.buf, state.win, state.jobid = -1, -1, -1
end

function M.simple_toggle(cmd_string, env_table, effective_config)
    if win_valid() then
        hide_window()
    elseif buf_valid() then
        open_window()
        focus_window()
    else
        spawn(cmd_string, env_table, effective_config, true)
    end
end

function M.focus_toggle(cmd_string, env_table, effective_config)
    if win_valid() then
        if vim.api.nvim_get_current_win() == state.win then
            hide_window()
        else
            focus_window()
        end
    elseif buf_valid() then
        open_window()
        focus_window()
    else
        spawn(cmd_string, env_table, effective_config, true)
    end
end

function M.get_active_bufnr()
    if buf_valid() then
        return state.buf
    end
    return nil
end

function M.is_available()
    return true
end

--- Notification controls (bound from keymaps) -------------------------------

-- Collapse the float into the corner notification.
function M.minimize()
    if not buf_valid() then
        vim.notify("Claude Code is not running.", vim.log.levels.WARN)
        return
    end
    hide_window()
    show_mini()
end

-- Bring the full float back (also dismisses the notification).
function M.restore()
    if buf_valid() then
        open_window()
        focus_window()
    else
        hide_mini()
    end
end

-- Flip between the float and the corner notification.
function M.toggle_mini()
    if mini_win_valid() then
        M.restore()
    elseif win_valid() then
        M.minimize()
    elseif buf_valid() then
        show_mini()
    else
        vim.notify("Claude Code is not running.", vim.log.levels.WARN)
    end
end

return M
