return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
        defaults = {
            ["<leader>f"] = { name = "Find (Telescope)" },
        }
    },
    keys = {
        {
            "<leader>?",
            function()
                require("which-key").show({ global = false })
            end,
            desc = "Buffer Local Keymaps (which-key)",
        },
    },
}
