local M = {}

local setup_diagnostic_config = function()
    local signs = {
        { name = "DiagnosticSignError", text = "" },
        { name = "DiagnosticSignWarn", text = "" },
        { name = "DiagnosticSignHint", text = "" },
        { name = "DiagnosticSignInfo", text = "" },
    }

    for _, sign in ipairs(signs) do
        vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
    end

    vim.diagnostic.config({
        underline = true,
        virtual_text = {
            severity = vim.diagnostic.severity.ERROR,
            source = true,
            spacing = 5,
        },
        signs = {
            active = signs,
        },
        severity_sort = true,
    })

    local which_key = require("which-key")
    which_key.add({
        {
            "]d",
            function()
                vim.diagnostic.goto_next()
            end,
            desc = "Next [d]iagnostic"
        },
        {
            "[d",
            function()
                vim.diagnostic.goto_prev()
            end,
            desc = "Prev [d]iagnostic"
        },
        {
            "<leader>du",
            function()
                vim.diagnostic.open_float()
            end
            ,
            desc = "[d]iagnostics [u]nder cursor"

        },
    })
end

local setup_custom_handlers = function()
    vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })

    vim.lsp.handlers["textDocument/signatureHelp"] =
        vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })
end

local setup_other_lsps = function(lspconfig)
    local vanilla = require("plugins.lsp.vanilla")

    --[[
    For a server which we want to customize significantly, like we are doing for
    `clangd` and `lua`, we would move it out of the list below, and have a file
    adjacent to this with the name of the server. See `clangd.lua` and
    `lua_ls.lua` for examples.
    --]]
    for _, server in ipairs({
        "bashls",
        "cmake",
        "dockerls",
        "dotls",
        "pyright",
        "ts_ls",
        "vimls",
        "yamlls",
    }) do
        lspconfig[server].setup({
            on_attach = function(client, bufnr)
                vanilla.setup_native_buffer_mappings(client, bufnr)
                vanilla.setup_plugin_buffer_mappings(client, bufnr)
                vanilla.setup_autocmds(client, bufnr)
            end,
            capabilities = vanilla.capabilities,
        })
    end

    lspconfig["jsonls"].setup({
        settings = {
            json = {
                schemas = require("schemastore").json.schemas(),
                validate = { enable = true },
            },
        },
        on_attach = function(client, bufnr)
            vanilla.setup_native_buffer_mappings(client, bufnr)
            vanilla.setup_plugin_buffer_mappings(client, bufnr)
            vanilla.setup_autocmds(client, bufnr)
        end,
        capabilities = vanilla.capabilities,
    })
end

function M.setup(mason, mason_lspconfig, lspconfig, neodev)
    --[[
  The sequence of operations in this method is important as per mason and
  neodev documentation
  - https://github.com/williamboman/mason.nvim
  - https://github.com/williamboman/mason-lspconfig.nvim
  - https://github.com/folke/lua-dev.nvim
  --]]
    -- [[
    mason.setup({
        ui = {
            icons = {
                server_installed = "✓",
                server_pending = "➜",
                server_uninstalled = "✗",
            },
        },
    })

    -- local ensure_installed = { "lua_ls" }
    mason_lspconfig.setup({
        ensure_installed = { "clangd", "lua_ls" },
        automatic_installation = true,
    })

    setup_diagnostic_config()
    setup_custom_handlers()

    -- `neodev` should be setup before we setup `lua_ls`
    neodev.setup()

    require("which-key").add({
        { "", group = "[L]SP" },
        { "", desc = "<leader>_", hidden = true }
    })

    require("plugins.lsp.clangd").custom_setup()
    require("plugins.lsp.lua_ls").custom_setup()

    setup_other_lsps(lspconfig)
    --]]
end

return M
