local M = {}

local get_capabilities = function()
    local cmp_nvim_lsp = require("cmp_nvim_lsp")
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    return cmp_nvim_lsp.default_capabilities(capabilities)
end

M.capabilities = get_capabilities()

M.setup_native_buffer_mappings = function(
    _, --[[ client --]]
    bufnr
)
    local lsp_prefix = function(desc)
        return "[l]sp: " .. desc
    end

    local which_key = require("which-key")
    which_key.add({
        { "<leader>lh", vim.lsp.buf.hover,          desc = lsp_prefix("[h]over documentation") },
        { "<leader>lk", vim.lsp.buf.signature_help, desc = lsp_prefix("[k] signature help") },
        { "<leader>ld", vim.lsp.buf.definition,     desc = lsp_prefix("goto [d]definition") },
        { "lD",         vim.lsp.buf.declaration,    desc = lsp_prefix("goto [D]eclaration") },
        {
            "<leader>lt",
            vim.lsp.buf.type_definition,
            desc = lsp_prefix("goto [t]ype definition"),
        },
        {
            "<leader>li",
            vim.lsp.buf.implementation,
            desc = lsp_prefix("goto [i]mplementation"),
        },
        {
            "<leader>lr",
            vim.lsp.buf.rename,
            desc = lsp_prefix("[r]ename identifier under cursor"),
        },
    })
end

M.setup_plugin_buffer_mappings = function(
    _, --[[ client --]]
    bufnr
)
    local which_key = require("which-key")

    --============================================================================
    -- https://github.com/nvim-telescope/telescope.nvim
    local telescope_builtin = require("telescope.builtin")
    which_key.add({
        {
            "<leader>lf",
            function()
                telescope_builtin.lsp_references(require("telescope.themes").get_ivy({
                    winblend = 20,
                }))
            end,
            desc = "[l]sp: re[f]erences in telescope",
        },
        {
            "<leader>sd",
            function()
                telescope_builtin.lsp_document_symbols(require("telescope.themes").get_ivy({
                    winblend = 20,
                }))
            end,
            desc = "lsp: search [s]symbols in [d]ocument",
        },
    })

    -----------------------------------------------------------------------------

    --============================================================================
    -- https://github.com/aznhe21/actions-preview.nvim
    which_key.add({
        {
            "<leader>la",
            function()
                require("actions-preview").code_actions()
            end,
            desc = "[l]sp: code [a]ctions",
        },
    })

    -----------------------------------------------------------------------------

    -----------------------------------------------------------------------------

    --============================================================================
    -- https://github.com/simrat39/symbols-outline.nvim
    which_key.add({
        { "<leader>lo", "<Cmd>SymbolsOutline<Cr>", desc = "[l]sp: symbols [o]utline" },
    })

    -----------------------------------------------------------------------------
end

M.setup_autocmds = function(client, bufnr)
    -- TODO: Replace following with an appropriate plugin
    -- Set autocommands conditional on server_capabilities
    if client.server_capabilities.document_highlight then
        local group = vim.api.nvim_create_augroup("lsp_document_highlight", { clear = true })
        vim.api.nvim_create_autocmd({ "CursorHold" }, {
            group = group,
            buffer = bufnr,
            callback = vim.lsp.buf.document_highlight,
        })
        vim.api.nvim_create_autocmd({ "CursorMoved" }, {
            group = group,
            buffer = bufnr,
            callback = vim.lsp.buf.clear_references,
        })
    end
end

return M
