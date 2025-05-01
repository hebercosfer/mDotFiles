require("commons.vim-options")

-- Initializing Lazy --
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- On VSCode or on Ordinary NeoVim
if vim.g.vscode then
	-- VSCode extension
	print("NeoVim for VSCode")
	require("lazy").setup("vs_plugins")
else
	-- ordinary Neovim
	print("NeoVim only")
	require("lazy").setup("clean_config")
	require("custom.floaterminal")
end

require("commons.lsp")
