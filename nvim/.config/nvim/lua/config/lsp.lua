vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then
      return
    end

    vim.notify("Attached to LSP " .. client.name, vim.log.levels.INFO)
    if client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = false })
    end
    if client.name == "clangd" then
      vim.keymap.set(
        "n",
        "<leader>ss",
        "<Cmd>LspClangdSwitchSourceHeader<Cr>",
        { desc = "Clangd: [S]witch [S]ource/Header file" }
      )
      vim.keymap.set(
        "n",
        "<leader>si",
        "<Cmd>LspClangdShowSymbolInfo<Cr>",
        { desc = "Clangd: [S]how Symbol [I]nfo" }
      )
    end
    vim.keymap.set(
      "n",
      "grd",
      "<Cmd>lua vim.lsp.buf.definition()<Cr>",
      { desc = "Clangd: [S]how Symbol [I]nfo" }
    )
  end,
})

vim.lsp.enable({ "lua_ls", "clangd", "cmake", "qmlls" })
vim.diagnostic.config({ virtual_text = true })
vim.keymap.set("i", "<c-space>", function()
  vim.lsp.completion.get()
end)
vim.cmd("set completeopt=menu,menuone,noinsert,noselect")
