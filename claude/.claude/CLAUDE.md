# Git workflow

- **Never run `git commit` in the agent shell.** Prepare the message, then launch the
  commit in a new tmux window so my own editor opens and I confirm it myself — I'm always
  in tmux:
  ```
  tmux new-window -n commit -c <repo> "git commit -e -F /tmp/cmsg.txt -- <paths>"
  ```
  - Use the pathspec form (`-- <paths>`) rather than `git add` first, so aborting leaves
    my index untouched. Sanity-check with `git commit --dry-run -F ... -- <paths>` first.
  - Do **not** append `; exec bash` or anything else that holds the window open — let it
    close itself once the commit finishes.
  - Never sweep unrelated modified files into the pathspec.
- **No `Co-Authored-By` or `Claude-Session` trailers** on any commit message.
- **Amends are exempt:** run `git commit --amend --no-edit` directly when I ask to amend.
  Never pass `-m` or otherwise rewrite the existing message on an amend.
- **Leave git's `core.editor` as `vi`.** Don't suggest switching it to `nvim` — I sometimes
  commit from inside a Neovim terminal buffer, and that would nest. Note the agent sandbox
  exports `GIT_EDITOR=true`, a no-op that silently skips the editor; verified it does not
  leak into tmux windows, which correctly resolve to `vi`.
- If commit text ever goes to a clipboard, use `xclip -selection clipboard` — never
  `clip.exe` (wrong clipboard, and it rewrites LF to CRLF).