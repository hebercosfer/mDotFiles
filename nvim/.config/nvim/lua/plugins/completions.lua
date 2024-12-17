local lazy_cmp_config = function()
    local cmp = require("cmp")
    local luasnip = require("luasnip")
    local lspkind = require("lspkind")
    cmp.setup({
        snippet = {
            expand = function(args)
                luasnip.lsp_expand(args.body)
            end,
        },
        mapping = {
            ["<C-n>"] = cmp.mapping(cmp.mapping.select_next_item(), { "i", "c" }),
            ["<Down>"] = cmp.mapping(cmp.mapping.select_next_item(), { "i", "c" }),
            ["<C-p>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "i", "c" }),
            ["<Up>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "i", "c" }),
            ["<C-d>"] = cmp.mapping(cmp.mapping.scroll_docs(4), { "i", "c" }),
            ["<C-u>"] = cmp.mapping(cmp.mapping.scroll_docs(-4), { "i", "c" }),
            ["<C-y>"] = cmp.mapping(cmp.mapping.confirm({ select = true }), { "i", "c" }),
            ["<C-e>"] = cmp.mapping({
                i = cmp.mapping.abort(),
                c = cmp.mapping.close(),
            }),
            ["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
        },
        sources = cmp.config.sources({
            {
                name = "nvim_lsp",
                priority = 1,
                -- entry_filter = function(entry, ctx)
                --     local kind = require("cmp.types").lsp.CompletionItemKind[entry.get_kind()]
                --     if kind == "Text" then return false end
                --     return true
                --end
            },
            { name = "nvim_lua", priority = 1 },
            { name = "vim_lsp",  priority = 2 },
            { name = "luasnip",  priority = 3 },
        }, {
            { name = "path",   priority = 9 },
            { name = "buffer", keyword_length = 4, priority = 8 },
        }),
        formatting = {
            fields = { "abbr", "kind", "menu" },
            format = lspkind.cmp_format({
                mode = "symbol", -- show only symbol annotations
                with_text = true,
                menu = {
                    nvim_lsp = "[LSP]",
                    nvim_lua = "[NVLUA]",
                    luasnip = "[SNIP]",
                    path = "[Path]",
                    buffer = "[BUF]",
                },
                maxwidth = 50, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
            }),
        },
        view = {
            entries = {
                name = "custom",
                selection_order = "near_cursor",
            },
        },
    })

    -- `/` cmdline setup.
    cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
            { name = "buffer" },
        },
    })

    -- `:` cmdline setup.
    cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
            { name = "path" },
        }, {
            { name = "cmdline" },
        }),
    })
end

local M = {
    {
        "hrsh7th/nvim-cmp",
        event = "InsertEnter",
        config = lazy_cmp_config,
        dependencies = {
            {
                "hrsh7th/cmp-nvim-lsp",
            },
            {
                "hrsh7th/cmp-nvim-lua",
            },
            {
                "hrsh7th/cmp-buffer",
            },
            {
                "hrsh7th/cmp-path",
            },
            {
                "hrsh7th/cmp-cmdline",
            },
            {
                "hrsh7th/cmp-emoji",
            },
            {
                "saadparwaiz1/cmp_luasnip",
            },
            {
                "L3MON4D3/LuaSnip",
            },
            {
                "onsails/lspkind-nvim",
            },
        },
    },
}

return M
-- return {
--     {
--         "hrsh7th/cmp-nvim-lsp",
--     },
--     {
--         "L3MON4D3/LuaSnip",
--         config = function()
--             local luasnip = require("luasnip")
--             luasnip.config.set_config({
--                 -- Remember to keep around the last snippet, so that we can jump back into it
--                 -- even if we move outside of the selection
--                 history = true,
--
--                 -- Updates as we type, useful for dynamic snippets
--                 updateevents = "TextChanged,TextChangedI",
--             })
--         end,
--         event = "InsertEnter",
--         dependencies = {
--             "rafamadriz/friendly-snippets",
--             "saadparwaiz1/cmp_luasnip",
--         },
--     },
--     -- {
--     --   "hrsh7th/nvim-cmp",
--     --   config = function()
--     --     local cmp = require("cmp")
--     --     require("luasnip.loaders.from_vscode").lazy_load()
--     --     local cmp_action = lsp_zero.cmp_action()
--
--     --     cmp.setup({
--     --       formatting = lsp_zero.cmp_format({ details = true }),
--     --       mapping = cmp.mapping.preset.insert({
--     --         ["<C-Space>"] = cmp.mapping.complete(),
--     --         ["<C-u>"] = cmp.mapping.scroll_docs(-4),
--     --         ["<C-d>"] = cmp.mapping.scroll_docs(4),
--     --         ["<C-f>"] = cmp_action.luasnip_jump_forward(),
--     --         ["<C-b>"] = cmp_action.luasnip_jump_backward(),
--     --       }),
--     --      snippet = {
--     --          expand = function(args)
--     --            require("luasnip").lsp_expand(args.body)
--     --          end,
--     --        },
--     --        window = {
--     --          completion = cmp.config.window.bordered(),
--     --          documentation = cmp.config.window.bordered(),
--     --        },
--     --        sources = cmp.config.sources({
--     --          { name = "nvim_lsp" },
--     --          { name = "luasnip" }, -- For luasnip users.
--     --          { name = "buffer" },
--     --        }),
--     --      })
--     --    end,
--     --  },
--     -- Autocompletion
--     {
--         "hrsh7th/nvim-cmp",
--         event = "InsertEnter",
--         dependencies = {
--             { "L3MON4D3/LuaSnip" },
--         },
--         config = function()
--             local cmp = require("cmp")
--             require("luasnip.loaders.from_vscode").lazy_load()
--             cmp.setup({
--                 sources = cmp.config.sources({
--                     { name = "nvim_lsp" },
--                     { name = "luasnip" }, -- For luasnip users.
--                     { name = "buffer" },
--                 }),
--                 mapping = {
--                     ["<CR>"] = cmp.mapping.confirm({ select = true }),
--                     ["<C-e>"] = cmp.mapping.abort(),
--                     ["<C-u>"] = cmp.mapping.scroll_docs(-4),
--                     ["<C-d>"] = cmp.mapping.scroll_docs(4),
--                     ["<Up>"] = cmp.mapping.select_prev_item(cmp_select_opts),
--                     ["<Down>"] = cmp.mapping.select_next_item(cmp_select_opts),
--                     ["<C-p>"] = cmp.mapping(function()
--                         if cmp.visible() then
--                             cmp.select_prev_item(cmp_select_opts)
--                         else
--                             cmp.complete()
--                         end
--                     end),
--                     ["<C-n>"] = cmp.mapping(function()
--                         if cmp.visible() then
--                             cmp.select_next_item(cmp_select_opts)
--                         else
--                             cmp.complete()
--                         end
--                     end),
--                 },
--                 snippet = {
--                     expand = function(args)
--                         require("luasnip").lsp_expand(args.body)
--                     end,
--                 },
--                 window = {
--                     completion = cmp.config.window.bordered(),
--                     documentation = cmp.config.window.bordered(),
--                 },
--             })
--             -- `/` cmdline setup.
--             cmp.setup.cmdline("/", {
--                 mapping = cmp.mapping.preset.cmdline(),
--                 sources = {
--                     { name = "buffer" },
--                 },
--             })
--             -- `:` cmdline setup.
--             cmp.setup.cmdline(":", {
--                 mapping = cmp.mapping.preset.cmdline(),
--                 sources = cmp.config.sources({
--                     { name = "path" },
--                 }, {
--                     {
--                         name = "cmdline",
--                         option = {
--                             ignore_cmds = { "Man", "!" },
--                         },
--                     },
--                 }),
--             })
--         end,
--  },
-- }
