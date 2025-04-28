return {
    "nvimdev/guard.nvim",
    dependencies = "nvimdev/guard-collection",
    event = "BufReadPre",
    config = function()
    	local ft = require("guard.filetype")
	ft("c,cpp,json"):fmt("clang-format")
	--[[ local augroup = vim.api.nvim_create_augroup("ClangLspFormatting", {}) ]]

	-- defaults
	vim.g.guard_config = {
	    -- format on write to buffer
            fmt_on_save = true,
    	    -- use lsp if no formatter was defined for this filetype
    	    lsp_as_default_formatter = false,
            -- whether or not to save the buffer after formatting
    	    save_on_fmt = true,
    	    -- automatic linting
            auto_lint = true,
    	    -- how frequently can linters be called
    	    lint_interval = 500
	}
    end,
}
