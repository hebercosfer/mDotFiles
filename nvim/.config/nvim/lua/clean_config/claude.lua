return {
    "coder/claudecode.nvim",
    opts = function()
        return {
            terminal = {
                provider = require("custom.claude_float"),
            },
            diff_opts = {
                -- Open the diff in its own full-screen tab instead of splitting
                -- the current layout into thirds.
                open_in_new_tab = true,
                -- Don't re-show the Claude terminal as a split in that tab; the
                -- float provider's watcher already minimizes it to the corner
                -- when a diff opens, so the tab is just old | proposed.
                hide_terminal_in_new_tab = true,
            },
        }
    end,
    keys = {
        { "<leader>a", nil, desc = "AI/Claude Code" },
        { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
        { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
        {
            "<leader>an",
            function()
                require("custom.claude_float").toggle_mini()
            end,
            desc = "Minimize Claude to notification",
        },
        { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
        { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
        { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
        { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
        { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
        {
            "<leader>as",
            "<cmd>ClaudeCodeTreeAdd<cr>",
            desc = "Add file",
            ft = { "NvimTree", "neo-tree" },
        },
        -- Diff management
        { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
        { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
    },
}
