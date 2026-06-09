-- Custom floating-terminal provider for claudecode.nvim.
-- Mirrors the centered/rounded style of custom/floaterminal.lua so Claude Code
-- opens in a floating window instead of a Snacks split.
--
-- Implements the claudecode.nvim terminal provider interface:
--   setup, open, close, simple_toggle, focus_toggle, get_active_bufnr, is_available

local M = {}

local state = {
    buf = -1,
    win = -1,
    jobid = -1,
}

local function buf_valid()
    return state.buf ~= -1 and vim.api.nvim_buf_is_valid(state.buf)
end

local function win_valid()
    return state.win ~= -1 and vim.api.nvim_win_is_valid(state.win)
end

local function open_window()
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
                if win_valid() and (not effective_config or effective_config.auto_close ~= false) then
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

return M
