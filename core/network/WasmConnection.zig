const std = @import("std");
const Allocator = std.mem.Allocator;
const OperationTable = @import("../network.zig").OperationTable;

const WasmConnection = @This();

pub const op_table = OperationTable{
    .read = undefined, // wasm doesn't have net package functionality
    .readNoBuffer = undefined, // wasm doesn't have net package functionality
    .write = undefined, // wasm doesn't have net package functionality
    .accept = undefined, // wasm doesn't have net package functionality
    .close = close,
    .destroy = destroy,
    .getAddr = undefined, // wasm doesn't have net package functionality
};

allocator: Allocator,

pub const Config = struct {};

pub fn init(allocator: Allocator, _: Config) !*WasmConnection {
    const self = try allocator.create(WasmConnection);
    self.* = WasmConnection{
        .allocator = allocator,
    };
    return self;
}

pub fn close(_: *anyopaque) void {}

pub fn destroy(ctx: *anyopaque) void {
    const self: *WasmConnection = @ptrCast(@alignCast(ctx));
    self.allocator.destroy(self);
}

/// Stub SynParser so that connection.zig can reference WebConnection.SynParser
/// on wasm targets (where WebConnection is aliased to WasmConnection).
pub const SynParser = struct {
    pub fn init(_: std.mem.Allocator) !@This() {
        return .{};
    }
    pub fn deinit(_: *@This()) void {}
    pub fn tryWebSocket(_: *@This(), _: anytype) !bool {
        return false;
    }
};
