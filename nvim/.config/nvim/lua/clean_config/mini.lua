-- lua/custom/plugins/mini.lua
return {
	{
		"echasnovski/mini.nvim",
		version = "*",
		enabled = true,
		config = function()
			local statusline = require("mini.statusline")
			statusline.setup({ use_icons = true })

			require("mini.surround").setup()
			require("mini.pairs").setup()
			require("mini.git").setup()
			require("mini.diff").setup()
		end,
	},
}
