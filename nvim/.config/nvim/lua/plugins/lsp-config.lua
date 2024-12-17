M = {
    {
        "stevearc/dressing.nvim",
        opts = {},
        event = "VeryLazy",
    },
    {
        -- https://github.com/neovim/nvim-lspconfig
        -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            {
                -- https://github.com/williamboman/mason.nvim
                "williamboman/mason.nvim",
            },
            {
                -- https://github.com/williamboman/mason-lspconfig.nvim
                "williamboman/mason-lspconfig.nvim",
            },
            {
                -- https://github.com/folke/lua-dev.nvimdot
                "folke/lua-dev.nvim",
            },
            {
                -- https://github.com/b0o/SchemaStore.nvim
                "b0o/schemastore.nvim",
            },
            {
                -- spec elsewhere
                "folke/which-key.nvim",
            },
            {
                -- spec elsewhere
                "nvim-telescope/telescope.nvim",
            },
            {
                -- spec elsewhere
                "hrsh7th/cmp-nvim-lsp",
            },
            {
                -- spec elsewhere
                "ray-x/lsp_signature.nvim",
            },
            {
                -- spec below
                "aznhe21/actions-preview.nvim",
            },
            {
                -- spec below
                "p00f/clangd_extensions.nvim",
            },
        },
        --[[
    For the core lsp config, its done outside the lazy spec folder as the
    configuration is internally modular and I would like to fuzzy find my way into
    a specific part of the config in future, eg keymaps, clangd, lua, python, etc..
    --]]
        config = function()
            -- plugins we installed
            local mason = require("mason")
            local mason_lspconfig = require("mason-lspconfig")
            local lspconfig = require("lspconfig")
            local neodev = require("neodev")

            require("plugins.lsp").setup(mason, mason_lspconfig, lspconfig, neodev)
        end
    },
    {
        -- https://github.com/aznhe21/actions-preview.nvim
        "aznhe21/actions-preview.nvim",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            {
                -- spec elsewhere
                "nvim-telescope/telescope.nvim",
            },
        },
        config = function()
            require("actions-preview").setup({
                telescope = require("telescope.themes").get_dropdown({
                    winblend = 20,
                }),
            })
        end,
    },
    {
        -- https://github.com/p00f/clangd_extensions.nvim
        "p00f/clangd_extensions.nvim",
        event = { "BufReadPre", "BufNewFile" },
        -- The `filetypes` come from the default `filetypes` specified for
        -- `clangd` in `lspconfig` documentation
        ft = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
        opts = {
            inlay_hints = {
                only_current_line = true,
                only_current_line_autocmd = { "CursorHold" },
            },
        },
    },
}

return M
