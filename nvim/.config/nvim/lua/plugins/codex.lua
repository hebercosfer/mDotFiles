-- hebercosfer's fork of codex.nvim, from the local checkout on feat/terminal-mcp-tools.
-- The checkout is used directly, so uncommitted work there is what Neovim loads.
-- Default mappings sit under <leader>c:
--   <leader>cc toggle   <leader>cC open   <leader>cs send (n, v)
--   <leader>cn new session   <leader>cy YOLO session
-- Terminal mode injects the Neovim MCP bridge (openDiff and the other editor tools)
-- into each Codex session it launches, using per-process --config overrides.
return {
  dir = vim.fn.expand '~/Workspace/codex.nvim-pr',
  name = 'codex.nvim',
  -- Its mappings are installed by setup(), so load before the first key press.
  event = 'VeryLazy',
  opts = {
    backend = 'app_server',
    app_server = {
      ui = 'terminal',
      dynamic_tools = true,
    },
    -- Close the Codex window with <C-x><C-m> instead of the default <C-q>.
    keymaps = { quit = '<C-x><C-m>' },
  },
}
