-- Match .stylua.toml (indent_width = 2) while typing, so new lines don't
-- start at the global shiftwidth of 4 and get reflowed on save.
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
vim.bo.expandtab = true
