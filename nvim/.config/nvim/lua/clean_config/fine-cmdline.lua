return {
    "VonHeikemen/fine-cmdline.nvim",
    config = function()
        vim.api.nvim_set_keymap("n", ":", "<cmd>FineCmdline<CR>", { noremap = true })
        vim.api.nvim_set_keymap("v", ":", "<cmd>FineCmdline '<,'><CR>", { noremap = true })
        vim.opt.cmdheight = 0
    end
}
