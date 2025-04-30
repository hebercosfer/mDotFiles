return {
    {
        -- https://github.com/williamboman/mason.nvim
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup(
                {
                    ui = {
                        icons = {
                            server_installed = "✓",
                            server_pending = "➜",
                            server_uninstalled = "✗",
                        },
                    },
                }
            )
        end,
    },
    {
        -- https://github.com/williamboman/mason-lspconfig.nvim
        "williamboman/mason-lspconfig.nvim",
        config = function()
            require("mason-lspconfig").setup({
                ensure_installed = { "lua_ls" },
            })
        end,
    },
    {
        -- spec elsewhere
        "hrsh7th/nvim-cmp",
    },
    {
        -- spec elsewhere
        "hrsh7th/cmp-nvim-lsp",
    },
    {
        "saadparwaiz1/cmp_luasnip"
    },
    {
        -- spec elsewhere
        "L3MON4D3/LuaSnip",
    }
}
