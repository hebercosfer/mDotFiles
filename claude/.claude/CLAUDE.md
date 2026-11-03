# Git workflow

- **Never run `git commit` in the agent shell.** Prepare the message, then launch the
  commit in a new tmux window so my own editor opens and I confirm it myself — I'm always
  in tmux:
  ```
  tmux new-window -n commit -c <repo> "git commit -e -v -F ~/.claude/cmsg.txt -- <paths>"
  ```
  - Keep `-v`: it appends the full staged diff below a scissors line, on top of git's
    usual template listing what is and isn't included, so the editor doubles as a last
    review before the commit lands. Everything below the scissors line is ignored.
  - Write `~/.claude/cmsg.txt` with a shell heredoc, **not** the Write tool — Write opens a
    diff for approval, which is pointless when I edit the message in the tmux window
    anyway. Don't show me a diff for a commit message.
  - **Not `/tmp/cmsg.txt`** — that was the old path and it cost two messages. `/tmp` is
    cleared on reboot and by `systemd-tmpfiles-clean`, so a commit window left open
    overnight loses its message file. `~/.claude/` survives. If a message is ever lost
    anyway, `.git/COMMIT_EDITMSG` still holds the last one git loaded, because it lives in
    the repo: recover it with `awk '/^#/{exit} {print}' .git/COMMIT_EDITMSG`.
  - If a commit window is closed or killed before it finishes, git leaves `.git/index.lock`
    behind and **every later git write fails** with "Unable to create index.lock". Check
    `fuser .git/index.lock` and `pgrep -af "git commit"` first — deleting a live lock can
    corrupt the index — then `rm .git/index.lock`.
  - Use the pathspec form (`-- <paths>`) rather than `git add` first, so aborting leaves
    my index untouched. Sanity-check with `git commit --dry-run -F ... -- <paths>` first.
    Untracked files are the exception: pathspecs can't match them, so they need
    `git add -N <path>` first (`git reset` undoes that if I abort).
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