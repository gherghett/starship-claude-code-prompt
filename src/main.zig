const std = @import("std");
const fs = std.fs;

pub fn main() void {
    run() catch return;
}

fn run() !void {
    const home = std.posix.getenv("HOME") orelse return;
    const pwd = std.posix.getenv("PWD") orelse return;

    // Build project dir name: /home/foo/bar -> -home-foo-bar
    var key_buf: [4096]u8 = undefined;
    var key_len: usize = 0;
    key_buf[0] = '-';
    key_len = 1;
    const pwd_no_slash = if (pwd.len > 0 and pwd[0] == '/') pwd[1..] else pwd;
    for (pwd_no_slash) |c| {
        if (key_len >= key_buf.len - 1) return;
        key_buf[key_len] = if (c == '/') '-' else c;
        key_len += 1;
    }
    const project_key = key_buf[0..key_len];

    // Build project path: ~/.claude/projects/<key>
    var proj_path_buf: [4096]u8 = undefined;
    const project_path = std.fmt.bufPrint(&proj_path_buf, "{s}/.claude/projects/{s}", .{ home, project_key }) catch return;

    var project_dir = fs.openDirAbsolute(project_path, .{ .iterate = true }) catch return;
    defer project_dir.close();

    // Find the most recently modified .jsonl file
    var newest_mtime: i128 = 0;
    var newest_name_buf: [256]u8 = undefined;
    var newest_name_len: usize = 0;

    var iter = project_dir.iterate();
    while (iter.next() catch return) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".jsonl")) continue;

        const stat = project_dir.statFile(entry.name) catch continue;
        if (stat.mtime > newest_mtime) {
            newest_mtime = stat.mtime;
            if (entry.name.len <= newest_name_buf.len) {
                @memcpy(newest_name_buf[0..entry.name.len], entry.name);
                newest_name_len = entry.name.len;
            }
        }
    }

    if (newest_name_len == 0) return;
    const newest_name = newest_name_buf[0..newest_name_len];

    // Session ID is filename without .jsonl
    const session_id = newest_name[0 .. newest_name.len - 6];

    // Count user messages by scanning the file
    const file = project_dir.openFile(newest_name, .{}) catch return;
    defer file.close();

    var msg_count: u32 = 0;
    var read_buf: [16384]u8 = undefined;

    while (true) {
        const bytes_read = file.read(&read_buf) catch break;
        if (bytes_read == 0) break;
        const data = read_buf[0..bytes_read];

        // Count occurrences of "type":"user" and "type": "user"
        var i: usize = 0;
        while (i + 13 <= data.len) : (i += 1) {
            if (std.mem.startsWith(u8, data[i..], "\"type\":\"user\"") or
                std.mem.startsWith(u8, data[i..], "\"type\": \"user\""))
            {
                msg_count += 1;
                i += 13;
            }
        }
    }

    if (msg_count == 0) return;

    // Compute relative time from mtime
    const now_ts = std.time.timestamp();
    const mtime_secs: i64 = @intCast(@divTrunc(newest_mtime, std.time.ns_per_s));
    const diff: u64 = @intCast(@max(0, now_ts - mtime_secs));

    var age_buf: [16]u8 = undefined;
    const age: []const u8 = if (diff < 60)
        "now"
    else if (diff < 3600)
        std.fmt.bufPrint(&age_buf, "{d}m", .{diff / 60}) catch "?"
    else if (diff < 86400)
        std.fmt.bufPrint(&age_buf, "{d}h", .{diff / 3600}) catch "?"
    else if (diff < 604800)
        std.fmt.bufPrint(&age_buf, "{d}d", .{diff / 86400}) catch "?"
    else
        std.fmt.bufPrint(&age_buf, "{d}w", .{diff / 604800}) catch "?";

    // Check if session is active
    var active = false;
    var sess_path_buf: [4096]u8 = undefined;
    const sessions_path = std.fmt.bufPrint(&sess_path_buf, "{s}/.claude/sessions", .{home}) catch return;

    if (fs.openDirAbsolute(sessions_path, .{ .iterate = true })) |dir_val| {
        var dir = dir_val;
        defer dir.close();
        var sess_iter = dir.iterate();
        while (sess_iter.next() catch null) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

            var sess_buf: [512]u8 = undefined;
            const sess_file = dir.openFile(entry.name, .{}) catch continue;
            const n = sess_file.read(&sess_buf) catch {
                sess_file.close();
                continue;
            };
            sess_file.close();

            if (std.mem.indexOf(u8, sess_buf[0..n], session_id) != null) {
                // Extract PID from filename (strip .json)
                const pid_str = entry.name[0 .. entry.name.len - 5];
                const pid = std.fmt.parseInt(std.posix.pid_t, pid_str, 10) catch break;
                // kill(pid, 0) - if it doesn't error, process is alive
                if (std.posix.kill(pid, 0)) |_| {
                    active = true;
                } else |_| {}
                break;
            }
        }
    } else |_| {}

    const stdout = std.io.getStdOut().writer();
    if (active) {
        stdout.print("\xe2\x9c\xbd {d}msg \xe2\x9c\xb3\n", .{msg_count}) catch return;
    } else {
        stdout.print("\xe2\x9c\xbd {d}msg {s}\n", .{ msg_count, age }) catch return;
    }
}
