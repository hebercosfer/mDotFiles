vim.o.tabstop = 4      -- Insert 4 spaces for a tab
vim.o.shiftwidth = 4   -- Change the number of space characters inserted for indentation
vim.o.expandtab = true -- Converts tabs to spacesvim.opt.clipboard = "unnamedplus"
vim.opt.number = true
vim.opt.relativenumber = true
vim.g.mapleader = " "
vim.g.background = "light"

vim.opt.swapfile = false

-- From Advent of NVIM --
vim.keymap.set("n", "<space><space>x", "<cmd>source %<CR>", { desc = "Sourcing current file"})
vim.keymap.set("n", "<space>x", ":.lua<CR>", { desc = "Executing current lua file"})
vim.keymap.set("v", "<space>x", ":lua<CR>", { desc = "Executing current lua selection"})


-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight when yanking (copying) text",
    group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

-- Navigate vim panes better
vim.keymap.set("n", "<c-k>", ":wincmd k<CR>")
vim.keymap.set("n", "<c-j>", ":wincmd j<CR>")
vim.keymap.set("n", "<c-h>", ":wincmd h<CR>")
vim.keymap.set("n", "<c-l>", ":wincmd l<CR>")
vim.keymap.set("n", "<c-s>", ":w<CR>")
vim.wo.number = true

vim.keymap.set("n", "<leader>qq", vim.cmd.Ex, { desc = "Inital NeoVim screen"})

vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")


-- next greatest remap ever : asbjornHaland
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]], { desc = "[y]ank continuosly"})
vim.keymap.set({ "n", "v" }, "<leader>Y", [["+Y]], { desc = "[Y]ank all line continuosly"})
vim.keymap.set({ "n", "v" }, "<leader>p", [["+p]], { desc = "[p]aste continuosly"})

vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)

vim.keymap.set("n", "<leader>bn", "<cmd>bnext<CR>")
vim.keymap.set("n", "<leader>bp", "<cmd>bprev<CR>")
vim.keymap.set("n", "<leader>en", "<cmd>cnext<CR>")
vim.keymap.set("n", "<leader>ep", "<cmd>cprev<CR>")
vim.keymap.set("n", "<leader>dn", "<cmd>lnext<CR>")
vim.keymap.set("n", "<leader>dp", "<cmd>lprev<CR>")
