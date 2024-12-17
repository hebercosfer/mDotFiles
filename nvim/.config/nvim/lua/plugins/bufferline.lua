return {
    "akinsho/bufferline.nvim",
    version = "v4.8",
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
        vim.opt.termguicolors = true
        require("bufferline").setup({
            options = {
                mode = "buffers",
                offsets = {
                    {
                        filetype = "neo-tree",
                        text = "Explorer  ",
                        separator = true,
                        text_align = "right",
                    },
                },
                diagnostics = "nvim_lsp",
                separator_style = { "", "" },
                modified_icon = "●",
                show_close_icon = false,
                show_buffer_close_icons = true
            },
        })
    end
}
