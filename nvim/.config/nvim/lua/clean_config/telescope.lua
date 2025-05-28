return {
    {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.8",
        dependencies = {
            "nvim-lua/plenary.nvim",
            { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
        },
        config = function()
            local telescope = require("telescope")
            local builtin = require("telescope.builtin")

            telescope.setup({
                pickers = {
                    find_files = {
                        theme = "ivy",
                    },
                    coloscheme = {
                        theme = "ivy",
                        enable_preview = true,
                    },
                },
                extensions = {
                    fzf = {},
                },
            })

            telescope.load_extension("fzf")

            vim.keymap.set(
                "n",
                "<leader>fh",
                builtin.help_tags,
                { desc = "Telescope: [f]ind [h]elp tags" }
            )
            vim.keymap.set(
                "n",
                "<leader>ff",
                builtin.find_files,
                { desc = "Telescope: [f]ind [f]iles" }
            )
            vim.keymap.set(
                "n",
                "<leader>fr",
                builtin.resume,
                { desc = "Telescope: [f]ind files [r]esume" }
            )
            vim.keymap.set(
                "n",
                "<leader>fd",
                builtin.lsp_definitions,
                { desc = "Telescope: [f]ind [d]efinitions" }
            )
            vim.keymap.set(
                "n",
                "<leader>fs",
                builtin.lsp_document_symbols,
                { desc = "Telescope: [f]ind [s]ymbols" }
            )
            vim.keymap.set(
                "n",
                "<leader>fm",
                builtin.lsp_implementations,
                { desc = "Telescope: [f]ind i[m]plementations" }
            )

            vim.keymap.set("n", "<leader>fc", function()
                builtin.find_files({
                    cwd = vim.fn.stdpath("config"),
                })
            end, { desc = "Telescope: [f]ind [c]onfig NeoVim files" })

            vim.keymap.set(
                "n",
                "<leader>bf",
                builtin.buffers,
                { desc = "Telescope: [f]ind [b]uffers" }
            )

            vim.keymap.set("n", "<leader>fn", function()
                builtin.find_files({
                    cwd = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy"),
                })
            end, { desc = "Telescope: [f]ind internal [n]eoVim files" })
            vim.keymap.set(
                { "n" },
                "<leader>cl",
                builtin.colorscheme,
                { desc = "Chose [c]o[l]ourschemes" }
            )

            require("custom.multigrep").setup()
        end,
    },
}
