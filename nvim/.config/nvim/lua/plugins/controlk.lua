return {
  {
    -- Private repository: SSH, because git has no credential helper here.
    url = "git@github.com:hebercosfer/telescope-controlk.nvim.git",
    name = "telescope-controlk.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("telescope").load_extension("controlk")
    end,
  },
}
