-- Codex.nvim review integration check.
-- Temporarily disabled custom setup while checking the plugin's defaults.
--[[
return {
  "ishiooon/codex.nvim",
  dependencies = { "folke/snacks.nvim" },
  lazy = false,
  config = function(_, opts)
    require("codex").setup(opts)

    local function deny_codex_diff()
      local diff = require("codex.diff")
      local current_buf = vim.api.nvim_get_current_buf()
      local tab_name = vim.b[current_buf].codex_diff_tab_name

      if not tab_name then
        diff.deny_current_diff()
        return
      end

      diff.deny_current_diff()
      diff.close_diff_by_tab_name(tab_name)
    end

    pcall(vim.api.nvim_del_user_command, "CodexDiffDeny")
    vim.api.nvim_create_user_command("CodexDiffDeny", deny_codex_diff, {
      desc = "Reject and close the current Codex diff",
    })

    local function get_visible_terminal_window(bufnr)
      if not bufnr then
        return nil
      end

      local bufinfo = vim.fn.getbufinfo(bufnr)[1]
      if not bufinfo or not bufinfo.windows then
        return nil
      end

      for _, win in ipairs(bufinfo.windows) do
        if vim.api.nvim_win_is_valid(win) then
          return win
        end
      end
    end

    local function toggle_codex_float(command_opts)
      local terminal = require("codex.terminal")
      local bufnr = terminal.get_active_terminal_bufnr()
      local win = get_visible_terminal_window(bufnr)
      local args = command_opts and command_opts.args ~= "" and command_opts.args or nil

      if win and vim.api.nvim_win_get_config(win).relative ~= "" then
        terminal.simple_toggle({}, args)
      else
        terminal.maximize_toggle({}, args)
      end
    end

    local function focus_codex_float(command_opts)
      local terminal = require("codex.terminal")
      local bufnr = terminal.get_active_terminal_bufnr()
      local win = get_visible_terminal_window(bufnr)

      if not win or vim.api.nvim_win_get_config(win).relative == "" then
        terminal.maximize_toggle({}, command_opts and command_opts.args ~= "" and command_opts.args or nil)
        return
      end

      vim.api.nvim_set_current_win(win)
      vim.cmd("startinsert")
    end

    vim.api.nvim_create_user_command("CodexFloat", toggle_codex_float, {
      nargs = "*",
      desc = "Toggle Codex in a floating terminal",
    })
    vim.api.nvim_create_user_command("CodexFloatFocus", focus_codex_float, {
      nargs = "*",
      desc = "Focus Codex in a floating terminal",
    })

    -- Make the plugin's usual :Codex entry point open in a float too.
    vim.api.nvim_del_user_command("Codex")
    vim.api.nvim_create_user_command("Codex", toggle_codex_float, {
      nargs = "*",
      desc = "Toggle Codex in a floating terminal",
    })

    vim.api.nvim_create_autocmd("TermOpen", {
      pattern = "*codex*",
      callback = function(ev)
        vim.keymap.set("t", "<C-x><C-m>", "<cmd>Codex<cr>", {
          buffer = ev.buf,
          desc = "Hide Codex to background",
        })
      end,
    })
  end,
  opts = {
    auto_start = true,
    terminal = {
      unfocus_key = "<C-]>",
      maximized_width_percentage = 0.8,
      maximized_height_percentage = 0.8,
    },
  },
  keys = {
    { "<leader>c", nil, desc = "Codex" },
    { "<leader>cc", "<cmd>CodexFloat<cr>", desc = "Toggle Codex (float)" },
    {
      "<leader>cc", "<cmd>CodexSend<cr>",
      mode = "v",
      desc = "Send to Codex",
    },
    { "<leader>cs", "<cmd>CodexFloat<cr>", desc = "Toggle Codex (float)" },
    { "<leader>cf", "<cmd>CodexFloatFocus<cr>", desc = "Focus Codex (float)" },
    { "<leader>cm", "<cmd>CodexFloat<cr>", desc = "Toggle Codex float" },
    { "<leader>cy", "<cmd>CodexDiffAccept<cr>", desc = "Accept Codex diff" },
    { "<leader>cn", "<cmd>CodexDiffDeny<cr>", desc = "Reject Codex diff" },
  },
}
]]

return {
  "ishiooon/codex.nvim",
  dependencies = { "folke/snacks.nvim" },
  -- Load at startup so the default auto_start initialization can expose MCP tools.
  lazy = false,
  config = true,
}
