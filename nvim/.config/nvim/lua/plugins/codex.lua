-- Official codex.nvim (based on coalio/codex.nvim), loaded from the local checkout.
-- The checkout is used directly, so uncommitted work there is what Neovim loads.
-- Plugin defaults accept diffs with <leader>ca and reject them with <leader>cd.
-- This config adds visual <leader>cc to send the current selection.
-- App Server starts the Neovim MCP bridge automatically. Codex sessions launched
-- here receive it directly; external Codex sessions use the bundled stdio helper.
return {
  dir = vim.fn.expand("~/Workspace/codex.nvim-pr"),
  name = "codex.nvim",
  -- Its mappings are installed by setup(), so load before the first key press.
  event = "VeryLazy",
  opts = {
    backend = "app_server",
    app_server = {
      ui = "terminal",
      dynamic_tools = true,
    },
    focus_after_send = true,
    -- Close the Codex window with <C-x><C-m> instead of the default <C-q>.
    keymaps = {
      quit = "<C-x><C-m>",
    },
  },
  config = function(_, opts)
    require("codex").setup(opts)
    vim.keymap.set("x", "<leader>cc", "<cmd>CodexSend<CR>", { desc = "Send selection to Codex" })
  end,
}
