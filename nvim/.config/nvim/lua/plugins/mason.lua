return {
  {
    -- https://github.com/williamboman/mason.nvim
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup({
        ui = {
          icons = {
            server_installed = "✓",
            server_pending = "➜",
            server_uninstalled = "✗",
          },
        },
      })
    end,
  },
  {
    -- https://github.com/williamboman/mason-lspconfig.nvim
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "clangd" },
        -- stylua ships an lspconfig entry (`stylua --lsp`), so installing the
        -- Mason package is enough for automatic_enable to attach it to every
        -- Lua buffer. conform runs the CLI instead; keep it out of LSP.
        automatic_enable = { exclude = { "stylua" } },
      })
    end,
  },
  {
    -- https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim
    -- mason-lspconfig only installs LSP servers; formatters need this.
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    config = function()
      require("mason-tool-installer").setup({
        ensure_installed = { "stylua", "shfmt" },
      })
    end,
  },
}
