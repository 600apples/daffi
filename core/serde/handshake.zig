const std = @import("std");
const json = std.json;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const serde = @import("../serde.zig");
const PLACEHOLDER = serde.PLACEHOLDER;
const UNIT_SEPARATOR = serde.UNIT_SEPARATOR;
const UNIT_SEPARATOR_SEQ = serde.UNIT_SEPARATOR_SEQ;

pub const Event = struct {
    type: []const u8,
    member: []const u8,

    pub fn fromJson(allocator: Allocator, data: []const u8) !json.Parsed(Event) {
        return try json.parseFromSlice(Event, allocator, data, .{});
    }

    pub fn toJson(self: *Event, allocator: Allocator) ![]const u8 {
        return try std.json.Stringify.valueAlloc(allocator, self, .{});
    }

    pub fn create(comptime conntype: []const u8, member: []const u8) Event {
        return .{ .type = conntype, .member = member };
    }
};

pub const Handshake = struct {
    meta: Meta,
    members: []const Member,

    const Member = struct {
        name: []const u8,
        methods: ?[][]const u8,
    };

    pub const MemberData = struct {
        name: []const u8,
        methods: []const u8, // comma separated list of methods
    };

    const Meta = struct {
        type: []const u8,
        // Set by the server on a rejection reply (e.g. duplicate app_name).
        // ``error`` is a Zig keyword → @"…" identifier syntax.
        @"error": ?[]const u8 = null,
        /// The connecting peer's `auth_token`, checked by a server that
        /// was given one.
        token: ?[]const u8 = null,
    };

    pub fn fromJson(allocator: Allocator, data: []const u8) !json.Parsed(Handshake) {
        return try json.parseFromSlice(Handshake, allocator, data, .{ .ignore_unknown_fields = true });
    }

    /// Whether `given` is the token a server expects; `expected` null
    /// accepts anyone.  Digests are compared so the time taken does not
    /// depend on how much of the token matched, or on its length.
    pub fn tokenMatches(expected: ?[]const u8, given: ?[]const u8) bool {
        const want = expected orelse return true;
        const Sha256 = std.crypto.hash.sha2.Sha256;
        var a: [Sha256.digest_length]u8 = undefined;
        var b: [Sha256.digest_length]u8 = undefined;
        Sha256.hash(want, &a, .{});
        Sha256.hash(given orelse "", &b, .{});
        return std.crypto.timing_safe.eql([Sha256.digest_length]u8, a, b) and given != null;
    }

    pub fn toJson(self: *Handshake, allocator: Allocator) ![]const u8 {
        return try std.json.Stringify.valueAlloc(allocator, self, .{});
    }

    pub fn create(allocator: Allocator, memberdata: []const MemberData, connection_type: ?[]const u8) !Handshake {
        var members = try allocator.alloc(Member, memberdata.len);
        var methods: ?[][]const u8 = undefined;
        for (memberdata, 0..) |md, mem_idx| {
            if (mem.eql(u8, md.methods, PLACEHOLDER)) {
                methods = null;
            } else {
                var methods_iterator = mem.splitScalar(u8, md.methods, UNIT_SEPARATOR);
                methods = try allocator.alloc([]const u8, mem.count(u8, md.methods, UNIT_SEPARATOR_SEQ) + 1);
                var mt_idx: usize = 0;
                while (methods_iterator.next()) |mt| : (mt_idx += 1) methods.?[mt_idx] = mem.trim(u8, mt, " ");
            }
            members[mem_idx] = .{ .name = md.name, .methods = methods };
        }
        return .{ .meta = .{ .type = connection_type orelse PLACEHOLDER }, .members = members };
    }

    /// Build a *rejection* handshake reply: empty member list, ``meta.error``
    /// set to *reason*.  The connecting peer parses the same JSON and
    /// inspects ``meta.error`` to detect that the handshake was refused.
    pub fn createRejection(allocator: Allocator, connection_type: []const u8, reason: []const u8) !Handshake {
        const members = try allocator.alloc(Member, 0);
        return .{
            .meta = .{
                .type = connection_type,
                .@"error" = reason,
            },
            .members = members,
        };
    }
};

test "handshake token check" {
    try std.testing.expect(Handshake.tokenMatches(null, null));
    try std.testing.expect(Handshake.tokenMatches(null, "anything"));
    try std.testing.expect(Handshake.tokenMatches("s3cret", "s3cret"));
    try std.testing.expect(!Handshake.tokenMatches("s3cret", "s3cre"));
    try std.testing.expect(!Handshake.tokenMatches("s3cret", null));
    try std.testing.expect(!Handshake.tokenMatches("", null));

    const parsed = try Handshake.fromJson(std.testing.allocator,
        \\{"meta":{"type":"client","token":"t","future":1},"members":[{"name":"a","methods":null}]}
    );
    defer parsed.deinit();
    try std.testing.expectEqualStrings("t", parsed.value.meta.token.?);
}
