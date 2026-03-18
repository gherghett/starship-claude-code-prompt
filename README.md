# starship-claude-code-prompt

A [Starship](https://starship.rs) custom module that shows your last Claude Code session in the current directory.

```
~/my-project ✽ 47msg 3h
~/my-project ✽ 12msg ✳       ← active right now
~/other-dir                    ← no claude sessions, nothing shown
```

Shows message count, how long ago the session was active, and whether it's running right now.

## Install

1. Copy the script somewhere on your path:

```bash
cp claude-session-info.sh ~/.config/claude-session-info.sh
chmod +x ~/.config/claude-session-info.sh
```

2. Add the module to your `~/.config/starship.toml`:

```toml
[custom.claude]
command = "~/.config/claude-session-info.sh"
when = "test -d ~/.claude/projects/$(echo $PWD | sed 's|^/||; s|/|-|g; s|^|-|')"
format = "[$output]($style) "
style = "bold #da7756"
shell = ["bash", "--noprofile", "--norc"]
```

That's it.

## What it reads

Claude Code stores session data in `~/.claude/`:

- `~/.claude/projects/<dir>/*.jsonl` — session transcripts (one per session, per directory)
- `~/.claude/sessions/*.json` — active session PIDs

The project directory name is your `$PWD` with slashes replaced by dashes (e.g. `/home/user/my-project` → `-home-user-my-project`). This means it's tied to the exact directory you started Claude from.

## What the output means

- `✽` — there's a Claude session here
- `47msg` — number of user messages in the most recent session
- `3h` / `2d` / `1w` — time since the session was last active
- `✳` — the session is running right now (replaces the time)

## Requirements

- [Starship](https://starship.rs)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- Linux (uses `stat -c` — macOS would need `stat -f`)
