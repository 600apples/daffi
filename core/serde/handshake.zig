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
        return try json.parseFromSlice(Event, allocator, data, .{ .ignore_unknown_fields = true });
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
        /// The registration a router gave this name (see `ChannelsMapper`);
        /// absent (0) from peers that predate it.
        generation: u16 = 0,
    };

    pub const MemberData = struct {
        name: []const u8,
        methods: []const u8, // comma separated list of methods
        generation: u16 = 0,
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

    // Must clear the join-broadcast fan-out integration test (≥520 peers)
    // and leave headroom for larger clusters; the old fixed bcast_conns
    // array was 512, membership itself is unbounded in the router.
    pub const max_members: usize = 1024;
    pub const max_methods: usize = 1024;
    pub const max_name_len: usize = 64;

    pub const Limits = struct {
        max_members: usize,
        max_methods: usize,
        max_name_len: usize,
    };

    /// For a handshake a server receives from a connecting peer.
    pub const peer_limits: Limits = .{ .max_members = max_members, .max_methods = max_methods, .max_name_len = max_name_len };
    /// For the reply a client gets from its server: a router lists every
    /// member of the cluster, so the per-peer caps do not apply.
    pub const reply_limits: Limits = .{ .max_members = std.math.maxInt(usize), .max_methods = std.math.maxInt(usize), .max_name_len = std.math.maxInt(usize) };

    /// Parse a handshake from an untrusted peer.
    pub fn fromJson(allocator: Allocator, data: []const u8) !json.Parsed(Handshake) {
        return fromJsonLimited(allocator, data, peer_limits);
    }

    /// Parse a server's handshake reply or member broadcast.
    pub fn fromJsonReply(allocator: Allocator, data: []const u8) !json.Parsed(Handshake) {
        return fromJsonLimited(allocator, data, reply_limits);
    }

    pub fn fromJsonLimited(allocator: Allocator, data: []const u8, limits: Limits) !json.Parsed(Handshake) {
        const parsed = try json.parseFromSlice(Handshake, allocator, data, .{ .ignore_unknown_fields = true });
        errdefer parsed.deinit();
        try parsed.value.validate(limits);
        return parsed;
    }

    pub fn validate(self: Handshake, limits: Limits) !void {
        if (self.members.len > limits.max_members) return error.TooManyMembers;
        for (self.members) |mb| {
            if (mb.name.len == 0 or mb.name.len > limits.max_name_len) return error.InvalidMemberName;
            if (mb.methods) |methods| {
                if (methods.len > limits.max_methods) return error.TooManyMethods;
                for (methods) |m| {
                    if (m.len == 0 or m.len > limits.max_name_len) return error.InvalidMethodName;
                }
            }
        }
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
            members[mem_idx] = .{ .name = md.name, .methods = methods, .generation = md.generation };
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

test "handshake rejects oversized membership" {
    try std.testing.expectError(error.InvalidMemberName, Handshake.fromJson(std.testing.allocator,
        \\{"meta":{"type":"client"},"members":[{"name":"","methods":null}]}
    ));
    const item = "{\"name\":\"a\",\"methods\":null}";
    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(std.testing.allocator);
    try body.appendSlice(std.testing.allocator, "{\"meta\":{\"type\":\"client\"},\"members\":[");
    for (0..Handshake.max_members + 1) |i| {
        if (i != 0) try body.append(std.testing.allocator, ',');
        try body.appendSlice(std.testing.allocator, item);
    }
    try body.appendSlice(std.testing.allocator, "]}");
    try std.testing.expectError(error.TooManyMembers, Handshake.fromJson(std.testing.allocator, body.items));
    // A router's reply lists the whole cluster.
    const reply = try Handshake.fromJsonReply(std.testing.allocator, body.items);
    defer reply.deinit();
    try std.testing.expectEqual(Handshake.max_members + 1, reply.value.members.len);
}

test "handshake member generation is optional on the wire" {
    const old = try Handshake.fromJsonReply(std.testing.allocator,
        \\{"meta":{"type":"router"},"members":[{"name":"a","methods":["f"]}]}
    );
    defer old.deinit();
    try std.testing.expectEqual(@as(u16, 0), old.value.members[0].generation);

    var arena = ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var hs = try Handshake.create(arena.allocator(), &.{.{ .name = "a", .methods = "f", .generation = 9 }}, "router");
    const parsed = try Handshake.fromJsonReply(std.testing.allocator, try hs.toJson(arena.allocator()));
    defer parsed.deinit();
    try std.testing.expectEqual(@as(u16, 9), parsed.value.members[0].generation);

    const event = try Event.fromJson(std.testing.allocator,
        \\{"type":"connected","member":"a","future":1}
    );
    defer event.deinit();
    try std.testing.expectEqualStrings("a", event.value.member);
}
