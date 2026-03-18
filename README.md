# starship-claude-code-prompt

A [Starship](https://starship.rs) custom module that shows your last Claude Code session in the current directory.

```
~/my-project ✽ 47msg 3h
~/my-project ✽ 12msg ✳       ← active right now
~/other-dir                    ← no claude sessions, nothing shown
```

Shows message count, how long ago the session was active, and whether it's running right now.

## Install

### Option A: Zig binary (faster, ~9ms vs ~60ms)

```bash
zig build -Doptimize=ReleaseSmall
cp zig-out/bin/claude-session-info ~/.local/bin/
```

### Option B: Shell script

```bash
cp claude-session-info.sh ~/.config/claude-session-info.sh
chmod +x ~/.config/claude-session-info.sh
```

### Starship config

Add to your `~/.config/starship.toml`:

```toml
[custom.claude]
command = "claude-session-info"  # or ~/.config/claude-session-info.sh for the script
when = "claude-session-info"     # or: test -d ~/.claude/projects/$(echo $PWD | sed 's|^/||; s|/|-|g; s|^|-|')
format = "[$output]($style) "
style = "bold #da7756"
shell = ["bash", "--noprofile", "--norc"]
```

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

## Compatibility

- The Zig binary works on Linux and macOS (uses Zig's std lib, no platform-specific syscalls)
- The shell script uses `stat -c %Y` which is Linux-only — on macOS, swap it for `stat -f %m`
- Reads Claude Code's internal session files (`~/.claude/`) which are undocumented and could change between versions. If they do, the module just silently hides itself

## Requirements

- [Starship](https://starship.rs)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
