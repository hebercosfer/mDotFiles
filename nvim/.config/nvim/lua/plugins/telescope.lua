return {
    {
        "nvim-lua/plenary.nvim",
    },
    {
        "nvim-telescope/telescope-file-browser.nvim",
    },
    {
        "benfowler/telescope-luasnip.nvim",
    },
    {
        "nvim-telescope/telescope-symbols.nvim",
    },
    {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.8",
        config = function()
            local telescope = require("telescope")
            local builtin = require("telescope.builtin")

            telescope.load_extension("fzf")
            telescope.load_extension("luasnip")
            telescope.load_extension("file_browser")

            telescope.setup({
                -- defaults = {
                -- 	file_ignore_patterns = {
                -- 		"^.git/",
                -- 	},
                -- },
                extensions = {
                    fzf = {},
                    file_browser = {},
                },
            })
            vim.keymap.set("n", "<leader>lf", function()
                builtin.lsp_references(require("telescope.themes").get_ivy({
                    winblend = 20,
                }))
            end, { desc = "[l]sp: re[f]erences in telescope" })
            vim.keymap.set("n", "<leader>sd", function()
                builtin.lsp_document_symbols(require("telescope.themes").get_ivy({
                    winblend = 20,
                }))
            end, { desc = "lsp: search [s]symbols in [d]ocument" })
            vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "lsp: [f]ind [f]iles" })
            vim.keymap.set("n", "<leader>lg", builtin.live_grep, { desc = "lsp: [l]ive [g]rep" })
            vim.keymap.set("n", "<leader>of", builtin.oldfiles, {})
            vim.keymap.set({ "n" }, "<leader>cl", function()
                builtin.colorscheme(require("telescope.themes").get_ivy({
                    enable_preview = true,
                    winblend = 30,
                }))
            end, { desc = "Chose [c]o[l]ourschemes", noremap = true })

            local current_buffer_fuzzy_find = function()
                -- You can pass additional configuration to telescope to change theme, layout, etc.
                builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
                    winblend = 10,
                    previewer = false,
                    skip_empty_lines = true,
                }))
            end

            vim.keymap.set({ "n" }, "<leader>/", function()
                current_buffer_fuzzy_find()
            end, { desc = "[/] Fuzzy search current buffer" })

            vim.keymap.set({ "n" }, "<leader>cl", function()
                builtin.colorscheme(require("telescope.themes").get_ivy({
                    enable_preview = true,
                    winblend = 30,
                }))
            end, { desc = "Chose [c]o[l]ourschemes" })

            vim.keymap.set({ "n" }, "\\s", function()
                builtin.resume()
            end, { desc = "Re[s]ume telescope" })

            require("custom.multigrep").setup()
        end,
        dependencies = {
            {
                "nvim-lua/plenary.nvim",
            },
            {
                -- spec elsewhere
                "folke/which-key.nvim",
            },
            {
                "nvim-tree/nvim-web-devicons",
            },
            { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
            {
                "nvim-telescope/telescope-file-browser.nvim",
            },
            {
                "benfowler/telescope-luasnip.nvim",
            },
            {
                "nvim-telescope/telescope-symbols.nvim",
            },
        },
    },
}
