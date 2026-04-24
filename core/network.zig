const is_wasm = @import("misc.zig").is_wasm;

pub const WasmConnection = @import("network/WasmConnection.zig");
// Native-only connection types: only imported for non-wasm targets to avoid
// pulling in std.net (removed in 0.16) when compiling for wasm.
pub const ClientConnection = if (is_wasm) WasmConnection else @import("network/ClientConnection.zig");
pub const WebConnection = if (is_wasm) WasmConnection else @import("network/WebConnection.zig");
pub const ServerConnection = if (is_wasm) WasmConnection else @import("network/ServerConnection.zig");
pub const Connection = @import("network/connection.zig").Connection;
pub const ConnectionType = @import("network/connection.zig").ConnectionType;
pub const OperationTable = @import("network/connection.zig").OperationTable;

test {
    _ = @import("network/connection.zig");
}
