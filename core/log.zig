//! Runtime-configurable logging for the native daffi layer.
//!
//! Python controls the level by calling  dfcore.setLogLevel(n)  where n maps:
//!   0 → debug, 1 → info, 2 → warning, 3 → error, 4 → off  (default)
//!
//! std_options sets compile-time log_level = .debug so that every
//! std.log.debug / .info / .warn / .err call site is compiled in even in
//! ReleaseFast.  The runtime check in logFn keeps them silent when Python has
//! not enabled logging.
//!
//! Output format (UTC, matching the Python daffi logger style):
//!
//!   DEBUG:   2026-04-25 15:43:12 | native[router] | message text
//!   INFO:    2026-04-25 15:43:12 | native[client] | message text
//!   WARNING: 2026-04-25 15:43:12 | native[server] | message text
//!   ERROR:   2026-04-25 15:43:12 | native[store]  | message text

const std   = @import("std");
const misc  = @import("misc.zig");
const epoch = std.time.epoch;

/// 0=debug  1=info  2=warning  3=error  4=off (default — silent)
var g_level = std.atomic.Value(u32).init(4);

pub fn setLevel(level: u32) void { g_level.store(level, .release); }
pub fn getLevel() u32           { return g_level.load(.acquire);   }

// ── helpers ────────────────────────────────────────────────────────────────

fn levelNum(comptime level: std.log.Level) u32 {
    return switch (level) {
        .debug => 0,
        .info  => 1,
        .warn  => 2,
        .err   => 3,
    };
}

/// Label text for each level.
fn levelLabel(comptime level: std.log.Level) []const u8 {
    return switch (level) {
        .debug => "DEBUG",
        .info  => "INFO",
        .warn  => "WARNING",
        .err   => "ERROR",
    };
}

/// Trailing spaces so that  "LABEL:"  fills exactly 9 characters:
///   "DEBUG:"   (6) → 3 spaces
///   "INFO:"    (5) → 4 spaces
///   "WARNING:" (8) → 1 space
///   "ERROR:"   (6) → 3 spaces
fn levelPad(comptime level: std.log.Level) []const u8 {
    return switch (level) {
        .debug => "   ",
        .info  => "    ",
        .warn  => " ",
        .err   => "   ",
    };
}

// ── POSIX write(2) ─────────────────────────────────────────────────────────
extern fn write(fd: c_int, buf: [*]const u8, count: usize) isize;

// ── logFn ──────────────────────────────────────────────────────────────────

/// Custom logFn registered via  pub const std_options  in core/core.zig.
///
/// All log levels are compiled in (log_level = .debug in std_options); we
/// do a single atomic load at the top to decide whether to actually print.
pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    if (comptime misc.is_wasm) return;

    // Runtime gate — one atomic load; returns immediately when silent.
    if (levelNum(level) < g_level.load(.acquire)) return;

    // ── build the full log line into a stack buffer ───────────────────────
    var buf: [2048]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);

    // Level label padded to 9 characters: "DEBUG:   " / "WARNING: " etc.
    w.writeAll(comptime levelLabel(level)) catch return;
    w.writeByte(':')                       catch return;
    w.writeAll(comptime levelPad(level))   catch return;

    // UTC timestamp  YYYY-MM-DD HH:MM:SS
    {
        var ts: std.c.timespec = undefined;
        _ = std.c.clock_gettime(.REALTIME, &ts);
        const secs: u64 = @intCast(ts.sec);
        const es = epoch.EpochSeconds{ .secs = secs };
        const ed = es.getEpochDay();
        const ds = es.getDaySeconds();
        const yd = ed.calculateYearDay();
        const md = yd.calculateMonthDay();
        w.print(" {d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
            yd.year,
            md.month.numeric(),
            md.day_index + 1,
            ds.getHoursIntoDay(),
            ds.getMinutesIntoHour(),
            ds.getSecondsIntoMinute(),
        }) catch return;
    }

    // Scope column  " | native[scope] | "
    w.print(" | native[{s}] | ", .{comptime @tagName(scope)}) catch return;

    // User message
    w.print(format ++ "\n", args) catch {
        w.writeAll("<message truncated>\n") catch {};
    };

    // Single write(2) call — atomic for writes up to PIPE_BUF (≥512 B)
    const written = std.Io.Writer.buffered(&w);
    _ = write(2, written.ptr, written.len);
}
