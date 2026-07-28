require("config.options")

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
  require("lazy").setup("vscode_plugins")
else
  -- ordinary Neovim
  require("lazy").setup("plugins")
  require("util.floaterminal")
end

require("config.lsp")
