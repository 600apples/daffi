//! OpenSSL TLS wrapper for server-side and client-side TLS.
//! All OpenSSL @cImport is confined to this file; callers use the opaque
//! handle types SslConn and SslCtx so they never depend on C headers.

const std = @import("std");

const c = @cImport({
    @cInclude("openssl/ssl.h");
    @cInclude("openssl/err.h");
});

/// Opaque handle for a per-connection SSL* object.
pub const SslConn = opaque {};

/// Opaque handle for a shared SSL_CTX* object.
pub const SslCtx = opaque {};

/// Initialize the OpenSSL library.
pub fn init() void {
    _ = c.OPENSSL_init_ssl(0, null);
}

/// Create a server-side TLS context, loading cert and private key from PEM files.
///
/// The returned SslCtx must be freed with freeCtx() when the server shuts down.
pub fn serverCtx(cert_file: [*:0]const u8, key_file: [*:0]const u8) !*SslCtx {
    const method = c.TLS_server_method() orelse return error.TlsInitFailed;
    const ctx = c.SSL_CTX_new(method) orelse return error.TlsInitFailed;
    if (c.SSL_CTX_use_certificate_file(ctx, cert_file, c.SSL_FILETYPE_PEM) <= 0) {
        c.SSL_CTX_free(ctx);
        return error.TlsCertLoadFailed;
    }
    if (c.SSL_CTX_use_PrivateKey_file(ctx, key_file, c.SSL_FILETYPE_PEM) <= 0) {
        c.SSL_CTX_free(ctx);
        return error.TlsKeyLoadFailed;
    }
    return @ptrCast(ctx);
}

/// Create a client-side TLS context.
///
/// If ca_file is non-empty, peer certificate verification is enabled using
/// that CA bundle (PEM file).  Passing an empty string disables verification
/// (connects without authenticating the server).
pub fn clientCtx(ca_file: [*:0]const u8) !*SslCtx {
    const method = c.TLS_client_method() orelse return error.TlsInitFailed;
    const ctx = c.SSL_CTX_new(method) orelse return error.TlsInitFailed;
    if (std.mem.len(ca_file) > 0) {
        if (c.SSL_CTX_load_verify_locations(ctx, ca_file, null) <= 0) {
            c.SSL_CTX_free(ctx);
            return error.TlsCaLoadFailed;
        }
        c.SSL_CTX_set_verify(ctx, c.SSL_VERIFY_PEER, null);
    } else {
        c.SSL_CTX_set_verify(ctx, c.SSL_VERIFY_NONE, null);
    }
    return @ptrCast(ctx);
}

/// Perform the server-side TLS handshake on an already-accepted TCP fd.
///
/// The returned SslConn must be freed with sslClose() when the connection ends.
/// The SslCtx is still owned by the caller (the ServerConnection).
pub fn serverHandshake(ctx: *SslCtx, fd: c_int) !*SslConn {
    const real_ctx: *c.SSL_CTX = @ptrCast(@alignCast(ctx));
    const ssl = c.SSL_new(real_ctx) orelse return error.TlsInitFailed;
    if (c.SSL_set_fd(ssl, fd) == 0) {
        c.SSL_free(ssl);
        return error.TlsSetFdFailed;
    }
    if (c.SSL_accept(ssl) <= 0) {
        c.SSL_free(ssl);
        return error.TlsHandshakeFailed;
    }
    return @ptrCast(ssl);
}

/// Perform the client-side TLS handshake on an already-connected TCP fd.
///
/// The returned SslConn must be freed with sslClose() when the connection ends.
/// The SslCtx is still owned by the caller (the ClientConnection).
pub fn clientHandshake(ctx: *SslCtx, fd: c_int) !*SslConn {
    const real_ctx: *c.SSL_CTX = @ptrCast(@alignCast(ctx));
    const ssl = c.SSL_new(real_ctx) orelse return error.TlsInitFailed;
    if (c.SSL_set_fd(ssl, fd) == 0) {
        c.SSL_free(ssl);
        return error.TlsSetFdFailed;
    }
    if (c.SSL_connect(ssl) <= 0) {
        c.SSL_free(ssl);
        return error.TlsHandshakeFailed;
    }
    return @ptrCast(ssl);
}

/// Read up to buf.len bytes in a single SSL_read call.
///
/// Returns the number of bytes read (0 on clean TLS close).  Does NOT loop —
/// use this wherever partial reads are acceptable (e.g. WebSocket framing,
/// HTTP upgrade parsing).
pub fn sslRead(conn: *SslConn, buf: []u8) !usize {
    const ssl: *c.SSL = @ptrCast(@alignCast(conn));
    const n = c.SSL_read(ssl, buf.ptr, @intCast(buf.len));
    if (n <= 0) {
        const err = c.SSL_get_error(ssl, n);
        if (err == c.SSL_ERROR_ZERO_RETURN) return 0; // clean close
        return error.TlsReadError;
    }
    return @intCast(n);
}

/// Read exactly buf.len bytes from a TLS connection (blocking loop).
///
/// Use this when you must fill the entire buffer before proceeding
/// (e.g. reading a fixed-size daffi message header or payload).
pub fn sslReadAll(conn: *SslConn, buf: []u8) !usize {
    var total: usize = 0;
    while (total < buf.len) {
        const n = try sslRead(conn, buf[total..]);
        if (n == 0) break; // clean close before buffer full
        total += n;
    }
    return total;
}

/// Write all bytes in data to a TLS connection (blocking).
pub fn sslWrite(conn: *SslConn, data: []const u8) !void {
    const ssl: *c.SSL = @ptrCast(@alignCast(conn));
    var sent: usize = 0;
    while (sent < data.len) {
        const n = c.SSL_write(ssl, data[sent..].ptr, @intCast(data.len - sent));
        if (n <= 0) return error.TlsWriteError;
        sent += @intCast(n);
    }
}

/// Shut down the TLS session and free the per-connection SSL object.
/// Does NOT free the SslCtx — that is owned by the ServerConnection or ClientConnection.
pub fn sslClose(conn: *SslConn) void {
    const ssl: *c.SSL = @ptrCast(@alignCast(conn));
    _ = c.SSL_shutdown(ssl);
    c.SSL_free(ssl);
}

/// Free a shared TLS context created by serverCtx() or clientCtx().
pub fn freeCtx(ctx: *SslCtx) void {
    const real_ctx: *c.SSL_CTX = @ptrCast(@alignCast(ctx));
    c.SSL_CTX_free(real_ctx);
}

/// A `net.Stream`-compatible adapter over a `*SslConn`.
///
/// Pass a `TlsStream` wherever a generic stream is expected (e.g. `Reader.readMessage`
/// or `Handshake.reply`) to route all I/O through the TLS layer.
///
/// The adapter does NOT own the underlying `SslConn`; the caller is responsible
/// for calling `sslClose` when the connection ends.
pub const TlsStream = struct {
    ssl: *SslConn,

    /// Read up to buf.len bytes in a single call.  Returns the number of bytes read.
    /// Callers that need exactly N bytes must loop (like Reader.readMessage does).
    pub fn read(self: TlsStream, buf: []u8) !usize {
        return sslRead(self.ssl, buf);
    }

    /// Write data and return the number of bytes written (always data.len on success).
    pub fn write(self: TlsStream, data: []const u8) !usize {
        try sslWrite(self.ssl, data);
        return data.len;
    }

    /// Write all of data, returning an error if the write cannot be completed.
    pub fn writeAll(self: TlsStream, data: []const u8) !void {
        return sslWrite(self.ssl, data);
    }
};
