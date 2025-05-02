vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if not client then
			return
		end

		print("Attached to LSP " .. client.name)
		if client:supports_method("textDocument/completion") then
			vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
		end
		if client.name == "clangd" then
			vim.api.nvim_buf_create_user_command(0, "LspClangdSwitchSourceHeader", function()
				require("custom.clangd").switch_source_header(0)
			end, { desc = "Switch between source/header" })

			vim.api.nvim_buf_create_user_command(0, "LspClangdShowSymbolInfo", function()
				require("custom.clangd").symbol_info()
			end, { desc = "Show symbol info" })
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
	end,
})

vim.lsp.config("*", {
	capabilities = require("blink.cmp").get_lsp_capabilities(),
})

vim.lsp.enable({ "lua_ls", "clangd", "cmake", "qmlls" })
vim.diagnostic.config({ virtual_text = true })

print("LSP Enabled")
