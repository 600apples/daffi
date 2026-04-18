//! Minimal POSIX/C-socket networking — replaces std.net (removed in Zig 0.16).
//! Requires linking with libc (-lc).

const c = @cImport({
    @cInclude("sys/socket.h");
    @cInclude("sys/un.h");
    @cInclude("netdb.h");
    @cInclude("unistd.h");
    @cInclude("arpa/inet.h");
    @cInclude("netinet/in.h");
    @cInclude("errno.h");
    @cInclude("string.h");
});

const std = @import("std");
const posix = std.posix;
const Allocator = std.mem.Allocator;


pub const Address = struct {
    bytes: [28]u8 = [_]u8{0} ** 28,
    family: u16 = 0,
    port: u16 = 0,

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        if (self.family == c.AF_INET) {
            const sa4: *const c.sockaddr_in = @ptrCast(@alignCast(&self.bytes));
            const ip = std.mem.bigToNative(u32, sa4.sin_addr.s_addr);
            try writer.print("{d}.{d}.{d}.{d}:{d}", .{
                (ip >> 24) & 0xff, (ip >> 16) & 0xff, (ip >> 8) & 0xff, ip & 0xff,
                self.port,
            });
        } else if (self.family == c.AF_INET6) {
            try writer.print("<ipv6>:{d}", .{self.port});
        } else if (self.family == c.AF_UNIX) {
            const sun: *const c.sockaddr_un = @ptrCast(@alignCast(&self.bytes));
            try writer.print("unix:{s}", .{std.mem.sliceTo(&sun.sun_path, 0)});
        } else {
            try writer.writeAll("<addr>");
        }
    }

    pub fn initUnix(path: []const u8) !Address {
        var sun: c.sockaddr_un = std.mem.zeroes(c.sockaddr_un);
        sun.sun_family = c.AF_UNIX;
        if (path.len >= sun.sun_path.len) return error.NameTooLong;
        @memcpy(sun.sun_path[0..path.len], path);
        var addr = Address{ .family = c.AF_UNIX };
        const len = @min(@sizeOf(c.sockaddr_un), addr.bytes.len);
        @memcpy(addr.bytes[0..len], std.mem.asBytes(&sun)[0..len]);
        return addr;
    }

    pub fn listen(self: *const Address, options: ListenOptions) !Server {
        return listenOn(self, options);
    }
};


pub const Stream = struct {
    handle: posix.socket_t,

    pub fn read(self: Stream, buf: []u8) !usize {
        const result = c.read(self.handle, buf.ptr, buf.len);
        if (result < 0) return error.ReadError;
        return @intCast(result);
    }

    pub fn readAll(self: Stream, buf: []u8) !usize {
        var total: usize = 0;
        while (total < buf.len) {
            const n = try self.read(buf[total..]);
            if (n == 0) break;
            total += n;
        }
        return total;
    }

    pub fn write(self: Stream, data: []const u8) !usize {
        const result = c.write(self.handle, data.ptr, data.len);
        if (result < 0) return error.WriteError;
        return @intCast(result);
    }

    pub fn writeAll(self: Stream, data: []const u8) !void {
        var sent: usize = 0;
        while (sent < data.len) {
            sent += try self.write(data[sent..]);
        }
    }

    pub fn close(self: Stream) void {
        _ = c.close(self.handle);
    }
};


pub fn tcpConnectToHost(_: Allocator, host: []const u8, port: u16) !Stream {
    var port_buf: [8]u8 = undefined;
    const port_str = std.fmt.bufPrintZ(&port_buf, "{d}", .{port}) catch return error.BadPort;

    var hints: c.addrinfo = std.mem.zeroes(c.addrinfo);
    hints.ai_family = c.AF_UNSPEC;
    hints.ai_socktype = c.SOCK_STREAM;

    var host_buf: [256]u8 = undefined;
    if (host.len >= host_buf.len) return error.NameTooLong;
    @memcpy(host_buf[0..host.len], host);
    host_buf[host.len] = 0;

    var res: ?*c.addrinfo = null;
    if (c.getaddrinfo(&host_buf, port_str.ptr, &hints, &res) != 0) return error.UnknownHostName;
    defer if (res) |r| c.freeaddrinfo(r);

    var it = res;
    while (it) |rp| : (it = rp.ai_next) {
        const fd = c.socket(rp.ai_family, rp.ai_socktype, rp.ai_protocol);
        if (fd < 0) continue;
        if (c.connect(fd, rp.ai_addr, rp.ai_addrlen) == 0) {
            return Stream{ .handle = fd };
        }
        _ = c.close(fd);
    }
    return error.ConnectionRefused;
}

pub fn connectUnixSocket(path: []const u8) !Stream {
    var sun: c.sockaddr_un = std.mem.zeroes(c.sockaddr_un);
    sun.sun_family = c.AF_UNIX;
    if (path.len >= sun.sun_path.len) return error.NameTooLong;
    @memcpy(sun.sun_path[0..path.len], path);

    const fd = c.socket(c.AF_UNIX, c.SOCK_STREAM, 0);
    if (fd < 0) return error.SocketCreateFailed;

    if (c.connect(fd, @ptrCast(&sun), @sizeOf(c.sockaddr_un)) != 0) {
        _ = c.close(fd);
        return error.ConnectionRefused;
    }
    return Stream{ .handle = fd };
}


pub const AddressList = struct {
    addrs: []Address,
    allocator: Allocator,

    pub fn deinit(self: *AddressList) void {
        self.allocator.free(self.addrs);
        self.allocator.destroy(self);
    }
};

pub fn getAddressList(allocator: Allocator, host: []const u8, port: u16) !*AddressList {
    var port_buf: [8]u8 = undefined;
    const port_str = std.fmt.bufPrintZ(&port_buf, "{d}", .{port}) catch return error.BadPort;

    var hints: c.addrinfo = std.mem.zeroes(c.addrinfo);
    hints.ai_family = c.AF_UNSPEC;
    hints.ai_socktype = c.SOCK_STREAM;

    var host_buf: [256]u8 = undefined;
    if (host.len >= host_buf.len) return error.NameTooLong;
    @memcpy(host_buf[0..host.len], host);
    host_buf[host.len] = 0;

    var res: ?*c.addrinfo = null;
    if (c.getaddrinfo(&host_buf, port_str.ptr, &hints, &res) != 0) return error.UnknownHostName;
    defer if (res) |r| c.freeaddrinfo(r);

    var count: usize = 0;
    var it = res;
    while (it) |rp| : (it = rp.ai_next) count += 1;

    const addrs = try allocator.alloc(Address, count);
    const list = try allocator.create(AddressList);
    list.* = .{ .addrs = addrs, .allocator = allocator };

    var idx: usize = 0;
    it = res;
    while (it) |rp| : (it = rp.ai_next) {
        var addr = Address{ .family = @intCast(rp.ai_family), .port = port };
        const len = @min(@sizeOf(Address), rp.ai_addrlen);
        @memcpy(addr.bytes[0..len], @as([*]const u8, @ptrCast(rp.ai_addr.?))[0..len]);
        addrs[idx] = addr;
        idx += 1;
    }
    return list;
}


pub const ListenOptions = struct {
    kernel_backlog: u31 = 128,
    reuse_address: bool = true,
};

pub const ServerConn = struct {
    stream: Stream,
    address: Address,
};

pub const Server = struct {
    handle: posix.socket_t,
    listen_address: Address,

    pub fn accept(self: *Server) !ServerConn {
        var addr_storage: c.sockaddr_storage = std.mem.zeroes(c.sockaddr_storage);
        var addr_len: c.socklen_t = @sizeOf(c.sockaddr_storage);
        const fd = c.accept(self.handle, @ptrCast(&addr_storage), &addr_len);
        if (fd < 0) return error.AcceptError;

        var addr = Address{ .family = addr_storage.ss_family };
        const copy_len = @min(@sizeOf(Address), addr_len);
        @memcpy(addr.bytes[0..copy_len], std.mem.asBytes(&addr_storage)[0..copy_len]);
        if (addr_storage.ss_family == c.AF_INET) {
            const sa4: *const c.sockaddr_in = @ptrCast(&addr_storage);
            addr.port = std.mem.bigToNative(u16, sa4.sin_port);
        } else if (addr_storage.ss_family == c.AF_INET6) {
            const sa6: *const c.sockaddr_in6 = @ptrCast(&addr_storage);
            addr.port = std.mem.bigToNative(u16, sa6.sin6_port);
        }
        return ServerConn{ .stream = .{ .handle = fd }, .address = addr };
    }

    pub fn deinit(self: *Server) void {
        _ = c.close(self.handle);
    }
};

fn listenOn(addr: *const Address, options: ListenOptions) !Server {
    const family: c_int = @intCast(addr.family);
    const fd = c.socket(family, c.SOCK_STREAM, 0);
    if (fd < 0) return error.SocketCreateFailed;

    if (options.reuse_address) {
        const opt: c_int = 1;
        _ = c.setsockopt(fd, c.SOL_SOCKET, c.SO_REUSEADDR, &opt, @sizeOf(c_int));
    }

    const sa: *const c.sockaddr = @ptrCast(@alignCast(&addr.bytes));
    const sa_len: c.socklen_t = switch (addr.family) {
        c.AF_INET => @sizeOf(c.sockaddr_in),
        c.AF_INET6 => @sizeOf(c.sockaddr_in6),
        c.AF_UNIX => @sizeOf(c.sockaddr_un),
        else => @sizeOf(c.sockaddr_storage),
    };

    if (c.bind(fd, sa, sa_len) != 0) {
        _ = c.close(fd);
        return error.AddressInUse;
    }
    if (c.listen(fd, options.kernel_backlog) != 0) {
        _ = c.close(fd);
        return error.ListenError;
    }
    return Server{ .handle = fd, .listen_address = addr.* };
}
