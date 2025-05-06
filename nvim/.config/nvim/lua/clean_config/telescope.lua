return {
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" }
    },
    config = function()
      local telescope = require("telescope")
      local builtin = require("telescope.builtin")


      telescope.setup {
        pickers = {
          find_files = {
            theme = "ivy"
          }
        },
        extensions = {
          fzf = {}
        }
      }

      telescope.load_extension("fzf")

      vim.keymap.set("n", "<space>fh", require("telescope.builtin").help_tags,
        { desc = "Telescope: [f]ind [h]elp tags" })
      vim.keymap.set("n", "<space>ff", require("telescope.builtin").find_files,
        { desc = "Telescope: [f]ind [f]iles" })

      vim.keymap.set("n", "<space>fc", function()
          builtin.find_files {
            cwd = vim.fn.stdpath("config")
          }
        end,
        { desc = "Telescope: [f]ind [c]onfig NeoVim files" })
      vim.keymap.set("n", "<space>fn", function()
          builtin.find_files {
            cwd = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy")
          }
        end,
        { desc = "Telescope: [f]ind internal [n]eoVim files" })

      require("custom.multigrep").setup()
    end
  }
}
