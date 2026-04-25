//! Re-exports all CFFI functions from client.zig and server.zig.

// --- server functions ---
pub const startServer               = @import("cffi/server.zig").startServer;
pub const stopServer                = @import("cffi/server.zig").stopServer;
pub const joinServer                = @import("cffi/server.zig").joinServer;
pub const detachServer              = @import("cffi/server.zig").detachServer;
pub const sendMessageFromServer     = @import("cffi/server.zig").sendMessageFromServer;
pub const getMessageForServerWorker = @import("cffi/server.zig").getMessageForServerWorker;
pub const setServiceMethods         = @import("cffi/server.zig").setServiceMethods;
pub const setWakeupFd               = @import("cffi/server.zig").setWakeupFd;

// --- client functions ---
pub const setLogLevel               = @import("cffi/client.zig").setLogLevel;
pub const startClient               = @import("cffi/client.zig").startClient;
pub const stopClient                = @import("cffi/client.zig").stopClient;
pub const sendMessageFromClient     = @import("cffi/client.zig").sendMessageFromClient;
pub const sendHandshakeFromClient   = @import("cffi/client.zig").sendHandshakeFromClient;
pub const getAvailableMembers       = @import("cffi/client.zig").getAvailableMembers;
pub const getMessageFromClientStore = @import("cffi/client.zig").getMessageFromClientStore;
pub const setTimeoutError           = @import("cffi/client.zig").setTimeoutError;
pub const getMessageForClientWorker = @import("cffi/client.zig").getMessageForClientWorker;
pub const setClientWakeupFd         = @import("cffi/client.zig").setClientWakeupFd;
pub const setClientDisconnectFd     = @import("cffi/client.zig").setClientDisconnectFd;
pub const setClientResponseFd       = @import("cffi/client.zig").setClientResponseFd;
