-- floating-claude.nvim as the plugin to configure, with claudecode.nvim as its
-- dependency: setup() sets claudecode.nvim up with the float as its terminal
-- and each diff in a tab of its own, and maps claudecode.nvim's commands.
-- Every option below is written out at its default, to change in place.
return {
  "hebercosfer/floating-claude.nvim",
  dependencies = { "coder/claudecode.nvim" },
  -- Its keys are mapped by setup(), not by lazy.nvim, so load it once the UI
  -- is up rather than on a key press.
  event = "VeryLazy",
  -- The unified diff below still splits its tab: claudecode.nvim opens the tab
  -- with an empty window, then vsplits the diff beside it. Close everything in
  -- that tab but the diff, so it fills the screen. Floats (the corner) stay,
  -- and a diff in your current tab (no tab_number) keeps your windows.
  -- Upstream closes a new-tab diff with :tabclose, so nothing misses the window.
  -- init = function()
  --   vim.api.nvim_create_autocmd("User", {
  --     pattern = "ClaudeCodeDiffOpened",
  --     callback = function(args)
  --       local d = args.data or {}
  --       if not d.tab_number or not (d.diff_window and vim.api.nvim_win_is_valid(d.diff_window)) then
  --         return
  --       end
  --       for _, w in ipairs(vim.api.nvim_tabpage_list_wins(d.tab_number)) do
  --         if w ~= d.diff_window and vim.api.nvim_win_get_config(w).relative == "" then
  --           pcall(vim.api.nvim_win_close, w, false)
  --         end
  --       end
  --     end,
  --   })
  -- end,
  opts = {
    -- The big centered float that hosts Claude.
    float = {
      width = 0.8, -- fraction of the editor (<= 1) or cells (> 1)
      height = 0.8,
      border = "rounded",
      title = " Claude Code ",
      title_pos = "center",
    },

    -- The corner Claude collapses into.
    notification = {
      width = 64,
      max_height = 12,
      refresh_ms = 120, -- how often the corner redraws while Claude works
      pulse_ms = 700, -- a running tool call's ⎿ flickers every pulse_ms / 2; false holds it still
      body = "sentence", -- "sentence" (opening sentence) or "block" (paragraph)
      -- "activity": Claude's latest message and what came after it;
      -- "messages": Claude's words, plus anything it needs you for;
      -- "events": as "activity", each line labelled `PreToolUse → …`.
      content = "activity",
      max_lines = 12, -- "block", when reading the screen: lines tailed
      gaps = 1, -- "block", when reading the screen: blank separators crossed
      border = "rounded",
      waiting = "Waiting for you", -- under the message while Claude waits on you; false for none
      status_in_title = true, -- Claude's state in the title, not the body
      title = " Claude ",
      title_pos = "center",
      zindex = 60,
      draggable = true, -- drag it out of the way with the mouse
    },

    -- Hear Claude through its hooks rather than read its screen; `keep` is how
    -- many events :FloatingClaudeEvents shows (0 keeps none). false reads the
    -- screen for everything.
    hooks = { enabled = true, keep = 50 },

    auto = {
      minimize_on_diff = true, -- minimize when an edit-approval diff opens
      -- What brings the float back from the corner: "idle" (a finished turn or
      -- a request), "request" (requests only), false (never).
      restore_on_input = "idle",
      -- What brings a hidden Claude back as the corner: "request", "idle" (a
      -- finished turn too), false (never). Reading the screen, which cannot
      -- tell a request from a finished turn, both levels act on either.
      show_hidden = "request",
      minimize_on_leave = true, -- minimize when focus leaves the float
      restore_on_enter = true, -- restore when the corner is entered (clicked)
      restore_idle_ms = 1200, -- wait after a finished turn before restoring
      watch_ms = 300, -- screen poll interval, when reading the screen
    },

    -- floating-claude's own mappings; false skips one.
    keymaps = {
      minimize = "<C-x><C-m>", -- terminal mode, inside the float
      hide = "<leader>aq", -- normal mode: float and corner off the screen
      events = "<leader>ae", -- normal mode: what the plugin heard from Claude
    },

    -- Mappings for claudecode.nvim's commands. Left as true, these are the keys
    -- claudecode.nvim's README suggests:
    --   <leader>ac  :ClaudeCode               <leader>ab  :ClaudeCodeAdd %
    --   <leader>af  :ClaudeCodeFocus          <leader>as  :ClaudeCodeSend (visual)
    --   <leader>ar  :ClaudeCode --resume      <leader>as  :ClaudeCodeTreeAdd (file trees)
    --   <leader>aC  :ClaudeCode --continue    <leader>aa  :ClaudeCodeDiffAccept
    --   <leader>am  :ClaudeCodeSelectModel    <leader>ad  :ClaudeCodeDiffDeny
    -- A list changes them: an entry on a default's key and mode replaces it,
    -- rhs false drops it ({ "<leader>aa", false }), anything else is added;
    -- `defaults = false` in the list starts from nothing. false maps none.
    keys = {
      { "<leader>ac", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
    },

    -- claudecode.nvim's own options, passed to its setup(). The terminal
    -- provider is set for you; the two tab options are what floating-claude
    -- sets anyway, written out here. false leaves claudecode.nvim to you.
    claudecode = {
      diff_opts = {
        -- One read-only buffer, removed lines red and struck through, added
        -- lines green, in place of old | proposed. Read-only: you can accept
        -- or deny, but not edit the proposal first. "vertical" is the default.
        -- layout = "unified",
        open_in_new_tab = true, -- each diff in a full-screen tab of its own
        hide_terminal_in_new_tab = true, -- no terminal split in that tab
      },
    },

    -- Warn once per session when claudecode.nvim / Claude Code are older than
    -- the pair floating-claude is built against.
    version_check = true,
  },
}
