return {
    "mfussenegger/nvim-dap",
    config = function()
        local dap = require("dap")
        vim.keymap.set("n", "<F5>", dap.continue, { desc = "Continue debugging" })
        vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Step over" })
        vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Step into" })
        vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Step out" })
        vim.keymap.set("n", "<Leader>dt", dap.toggle_breakpoint, { desc = "Toggle Breakpoint" })
        vim.keymap.set("n", "<Leader>db", dap.set_breakpoint, { desc = "Set Breakpoint" })
        vim.keymap.set("n", "<Leader>dp", function()
            dap.set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
        end, { desc = "Log Message" })
        vim.keymap.set("n", "<Leader>dr", dap.repl.open, { desc = "Open REPL" })
        vim.keymap.set("n", "<Leader>dl", dap.run_last, { desc = "Run last" })

        local widgets = require("dap.ui.widgets")
        vim.keymap.set({ "n", "v" }, "<Leader>dh", widgets.hover, { desc = "Hover on DAP UI" })
        vim.keymap.set({ "n", "v" }, "<Leader>dp", widgets.preview, { desc = "Preiew on DAP UI" })
        vim.keymap.set("n", "<Leader>df", function()
            widgets.centered_float(widgets.frames)
        end)
        vim.keymap.set("n", "<Leader>ds", function()
            widgets.centered_float(widgets.scopes)
        end)
    end,
}
