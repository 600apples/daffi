//! OpenSSL TLS wrapper for server-side and client-side TLS.
//! All OpenSSL C bindings are confined to this file; callers use the opaque
//! handle types SslConn and SslCtx so they never depend on C headers.
//!
//! Threading model
//! ---------------
//! An OpenSSL `SSL*` must not be used from two threads at once, yet a daffi
//! connection has one reader thread (blocked waiting for the next message) and
//! any number of writer threads.  To make that safe every `SslConn` is a small
//! `Session` that owns the `SSL*` together with a mutex, and the socket is put
//! into non-blocking mode once the handshake is done.  Each SSL_read/SSL_write
//! attempt takes the mutex, and when OpenSSL reports WANT_READ/WANT_WRITE the
//! mutex is released while we `poll()` for the socket.  A reader that is
//! "blocked" therefore never holds the lock.

const std = @import("std");
const net = @import("posix_net.zig");
const Mutex = @import("../misc.zig").Mutex;

const c = @import("openssl_c");

const log = std.log.scoped(.tls);
const allocator = std.heap.c_allocator;

/// Opaque handle for a per-connection TLS session.
pub const SslConn = opaque {};

/// Opaque handle for a shared SSL_CTX* object.
pub const SslCtx = opaque {};

/// Longest we wait for the socket to become writable before giving up on a
/// stalled peer.
const WRITE_STALL_TIMEOUT_MS: c_int = 30_000;
/// Longest a TLS handshake may take on a still-blocking socket.
pub const HANDSHAKE_TIMEOUT_MS: u32 = 5_000;

const Session = struct {
    ssl: *c.SSL,
    fd: c_int,
    mutex: Mutex = .{},
};

fn session(conn: *SslConn) *Session {
    return @ptrCast(@alignCast(conn));
}

/// Initialize the OpenSSL library.
pub fn init() void {
    _ = c.OPENSSL_init_ssl(0, null);
}

fn configureCtx(ctx: *c.SSL_CTX) void {
    // TLS 1.0/1.1 are deprecated (RFC 8996) and OpenSSL's default floor is
    // lower than that on some distributions.
    _ = c.SSL_CTX_ctrl(ctx, c.SSL_CTRL_SET_MIN_PROTO_VERSION, c.TLS1_2_VERSION, null);
    // Writers retry SSL_write after WANT_WRITE with the same data, but the
    // buffer address is not guaranteed to be identical on every call.
    _ = c.SSL_CTX_ctrl(ctx, c.SSL_CTRL_MODE, c.SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER, null);
}

/// True when `blob` looks like PEM material rather than a filesystem path.
/// Paths never start with the PEM armour; inline certs/keys/CAs always do.
fn isPemMaterial(blob: []const u8) bool {
    const trimmed = std.mem.trimStart(u8, blob, " \t\r\n");
    return std.mem.startsWith(u8, trimmed, "-----BEGIN ");
}

fn bioFromPem(pem: []const u8) !*c.BIO {
    if (pem.len > std.math.maxInt(c_int)) return error.TlsInitFailed;
    return c.BIO_new_mem_buf(pem.ptr, @intCast(pem.len)) orelse error.TlsInitFailed;
}

fn useCertificate(ctx: *c.SSL_CTX, cert: []const u8) !void {
    if (isPemMaterial(cert)) {
        const bio = try bioFromPem(cert);
        defer _ = c.BIO_free(bio);
        const x509 = c.PEM_read_bio_X509(bio, null, null, null) orelse return error.TlsCertLoadFailed;
        // SSL_CTX_use_certificate up-refs; we still own x509.
        defer _ = c.X509_free(x509);
        if (c.SSL_CTX_use_certificate(ctx, x509) <= 0) return error.TlsCertLoadFailed;
        // Remaining certs in the PEM are the chain (fullchain.pem style).
        while (c.PEM_read_bio_X509(bio, null, null, null)) |extra| {
            // add_extra_chain_cert takes ownership of extra on success.
            if (c.SSL_CTX_add_extra_chain_cert(ctx, extra) <= 0) {
                _ = c.X509_free(extra);
                return error.TlsCertLoadFailed;
            }
        }
        // EOF leaves an error on the OpenSSL queue; clear it.
        _ = c.ERR_clear_error();
        return;
    }
    const path = try allocator.dupeSentinel(u8, cert, 0);
    defer allocator.free(path);
    if (c.SSL_CTX_use_certificate_file(ctx, path.ptr, c.SSL_FILETYPE_PEM) <= 0) {
        return error.TlsCertLoadFailed;
    }
}

fn usePrivateKey(ctx: *c.SSL_CTX, key: []const u8) !void {
    if (isPemMaterial(key)) {
        const bio = try bioFromPem(key);
        defer _ = c.BIO_free(bio);
        const pkey = c.PEM_read_bio_PrivateKey(bio, null, null, null) orelse return error.TlsKeyLoadFailed;
        defer _ = c.EVP_PKEY_free(pkey);
        if (c.SSL_CTX_use_PrivateKey(ctx, pkey) <= 0) return error.TlsKeyLoadFailed;
        return;
    }
    const path = try allocator.dupeSentinel(u8, key, 0);
    defer allocator.free(path);
    if (c.SSL_CTX_use_PrivateKey_file(ctx, path.ptr, c.SSL_FILETYPE_PEM) <= 0) {
        return error.TlsKeyLoadFailed;
    }
}

fn loadCa(ctx: *c.SSL_CTX, ca: []const u8) !void {
    if (isPemMaterial(ca)) {
        const store = c.SSL_CTX_get_cert_store(ctx) orelse return error.TlsInitFailed;
        const bio = try bioFromPem(ca);
        defer _ = c.BIO_free(bio);
        var loaded: usize = 0;
        while (c.PEM_read_bio_X509(bio, null, null, null)) |x509| {
            const rc = c.X509_STORE_add_cert(store, x509);
            _ = c.X509_free(x509);
            if (rc <= 0) {
                // Duplicate certs in a bundle are fine; anything else fails.
                _ = c.ERR_clear_error();
            } else {
                loaded += 1;
            }
        }
        _ = c.ERR_clear_error();
        if (loaded == 0) return error.TlsCaLoadFailed;
        return;
    }
    const path = try allocator.dupeSentinel(u8, ca, 0);
    defer allocator.free(path);
    if (c.SSL_CTX_load_verify_locations(ctx, path.ptr, null) <= 0) {
        return error.TlsCaLoadFailed;
    }
}

/// Create a server-side TLS context from a certificate and private key.
///
/// Each argument is either a filesystem path to a PEM file, or the PEM
/// material itself (detected by a leading ``-----BEGIN `` armour).
///
/// When `ca` is non-empty, mutual TLS is enabled: clients must present a
/// certificate that chains to that CA (`SSL_VERIFY_PEER` +
/// `SSL_VERIFY_FAIL_IF_NO_PEER_CERT`).
///
/// The returned SslCtx must be freed with freeCtx() when the server shuts down.
pub fn serverCtx(cert: []const u8, key: []const u8, ca: []const u8) !*SslCtx {
    const method = c.TLS_server_method() orelse return error.TlsInitFailed;
    const ctx = c.SSL_CTX_new(method) orelse return error.TlsInitFailed;
    errdefer c.SSL_CTX_free(ctx);
    configureCtx(ctx);
    try useCertificate(ctx, cert);
    try usePrivateKey(ctx, key);
    if (c.SSL_CTX_check_private_key(ctx) != 1) return error.TlsKeyMismatch;
    if (ca.len > 0) {
        try loadCa(ctx, ca);
        const verify_mode: c_int = c.SSL_VERIFY_PEER | c.SSL_VERIFY_FAIL_IF_NO_PEER_CERT;
        c.SSL_CTX_set_verify(ctx, verify_mode, null);
        if (c.SSL_CTX_get_verify_mode(ctx) != verify_mode) return error.TlsInitFailed;
        // Advertise acceptable client CAs (path form only; PEM skips this —
        // VERIFY_FAIL_IF_NO_PEER_CERT still rejects bare clients).
        if (!isPemMaterial(ca)) {
            const path = try allocator.dupeSentinel(u8, ca, 0);
            defer allocator.free(path);
            if (c.SSL_load_client_CA_file(path.ptr)) |list| {
                c.SSL_CTX_set_client_CA_list(ctx, list);
            }
        }
    }
    return @ptrCast(ctx);
}

/// Create a client-side TLS context.
///
/// If `ca` is non-empty, peer certificate verification is enabled using that
/// CA bundle (filesystem path or PEM material); the server's certificate must
/// also match the host name passed to `clientHandshake` (skipped for Unix
/// paths).  Passing an empty string disables verification.
///
/// When `cert` and `key` are non-empty, they are presented as the client
/// identity (mutual TLS).
pub fn clientCtx(ca: []const u8, cert: []const u8, key: []const u8) !*SslCtx {
    const method = c.TLS_client_method() orelse return error.TlsInitFailed;
    const ctx = c.SSL_CTX_new(method) orelse return error.TlsInitFailed;
    errdefer c.SSL_CTX_free(ctx);
    configureCtx(ctx);
    if (ca.len > 0) {
        try loadCa(ctx, ca);
        c.SSL_CTX_set_verify(ctx, c.SSL_VERIFY_PEER, null);
    } else {
        c.SSL_CTX_set_verify(ctx, c.SSL_VERIFY_NONE, null);
    }
    if (cert.len > 0 or key.len > 0) {
        if (cert.len == 0 or key.len == 0) return error.TlsCertRequired;
        try useCertificate(ctx, cert);
        try usePrivateKey(ctx, key);
        if (c.SSL_CTX_check_private_key(ctx) != 1) return error.TlsKeyMismatch;
    }
    return @ptrCast(ctx);
}

fn newSession(ctx: *SslCtx, fd: c_int) !*Session {
    const real_ctx: *c.SSL_CTX = @ptrCast(@alignCast(ctx));
    const ssl = c.SSL_new(real_ctx) orelse return error.TlsInitFailed;
    errdefer c.SSL_free(ssl);
    if (c.SSL_set_fd(ssl, fd) == 0) return error.TlsSetFdFailed;
    const s = try allocator.create(Session);
    s.* = .{ .ssl = ssl, .fd = fd };
    return s;
}

/// Perform the server-side TLS handshake on an already-accepted TCP fd.
///
/// The socket must still be in blocking mode (ideally with I/O timeouts set);
/// call `finishHandshake` once any further blocking probing is done.
/// The returned SslConn must be freed with sslClose() when the connection ends.
/// The SslCtx is still owned by the caller (the ServerConnection).
pub fn serverHandshake(ctx: *SslCtx, fd: c_int) !*SslConn {
    const real_ctx: *c.SSL_CTX = @ptrCast(@alignCast(ctx));
    const s = try newSession(ctx, fd);
    errdefer {
        c.SSL_free(s.ssl);
        allocator.destroy(s);
    }
    // Re-apply the CTX verify mode on the SSL object (defensive; normally
    // inherited by SSL_new) so mTLS cannot be silently dropped.
    const mode = c.SSL_CTX_get_verify_mode(real_ctx);
    c.SSL_set_verify(s.ssl, mode, null);
    c.ERR_clear_error();
    if (c.SSL_accept(s.ssl) <= 0) return error.TlsHandshakeFailed;
    if ((mode & c.SSL_VERIFY_FAIL_IF_NO_PEER_CERT) != 0) {
        const peer = c.SSL_get_peer_certificate(s.ssl);
        if (peer == null) return error.TlsHandshakeFailed;
        _ = c.X509_free(peer);
        if (c.SSL_get_verify_result(s.ssl) != c.X509_V_OK) return error.TlsHandshakeFailed;
    }
    return @ptrCast(s);
}

/// Perform the client-side TLS handshake on an already-connected TCP fd.
///
/// `host` is sent as SNI and, when the context verifies peers, checked against
/// the certificate (as an IP address if it parses as one, else as a DNS name).
/// Unix-domain socket paths (containing ``/``) skip SNI / hostname checks —
/// peer authentication is the certificate / CA alone.
/// The returned SslConn must be freed with sslClose() when the connection ends.
/// The SslCtx is still owned by the caller (the ClientConnection).
pub fn clientHandshake(ctx: *SslCtx, fd: c_int, host: []const u8) !*SslConn {
    const s = try newSession(ctx, fd);
    errdefer {
        c.SSL_free(s.ssl);
        allocator.destroy(s);
    }
    const is_unix_path = std.mem.indexOfScalar(u8, host, '/') != null;
    if (host.len > 0 and !is_unix_path) {
        var host_buf: [256]u8 = undefined;
        if (host.len >= host_buf.len) return error.NameTooLong;
        @memcpy(host_buf[0..host.len], host);
        host_buf[host.len] = 0;
        const host_z: [*:0]const u8 = @ptrCast(&host_buf);
        const param = c.SSL_get0_param(s.ssl);
        if (isIpLiteral(host)) {
            if (c.X509_VERIFY_PARAM_set1_ip_asc(param, host_z) != 1) return error.TlsHostInvalid;
        } else {
            _ = c.SSL_ctrl(s.ssl, c.SSL_CTRL_SET_TLSEXT_HOSTNAME, c.TLSEXT_NAMETYPE_host_name, @ptrCast(@constCast(host_z)));
            if (c.SSL_set1_host(s.ssl, host_z) != 1) return error.TlsHostInvalid;
        }
    }

    c.ERR_clear_error();
    if (c.SSL_connect(s.ssl) <= 0) return error.TlsHandshakeFailed;
    return @ptrCast(s);
}

fn isIpLiteral(host: []const u8) bool {
    if (std.mem.indexOfScalar(u8, host, ':') != null) return true; // IPv6
    if (host.len == 0) return false;
    for (host) |ch| {
        if (!(ch >= '0' and ch <= '9') and ch != '.') return false;
    }
    return true;
}

/// Switch the connection to its steady-state I/O mode: non-blocking socket
/// with no kernel-level timeouts, all waiting done by `poll()` outside the
/// session lock.  Must be called once, after the handshake and after any
/// blocking probe reads.
pub fn finishHandshake(conn: *SslConn) void {
    const s = session(conn);
    (net.Stream{ .handle = s.fd }).setIoTimeout(0);
    net.setNonBlocking(s.fd);
}

/// Read up to buf.len bytes in a single logical SSL_read.
///
/// Returns the number of bytes read (0 on clean TLS close or when the peer
/// dropped the TCP connection).  Does NOT loop — use this wherever partial
/// reads are acceptable (e.g. WebSocket framing, HTTP upgrade parsing).
pub fn sslRead(conn: *SslConn, buf: []u8) !usize {
    const s = session(conn);
    if (buf.len == 0) return 0;
    const len: c_int = @intCast(@min(buf.len, std.math.maxInt(c_int)));
    while (true) {
        s.mutex.lock();
        c.ERR_clear_error();
        const n = c.SSL_read(s.ssl, buf.ptr, len);
        const err = if (n > 0) c.SSL_ERROR_NONE else c.SSL_get_error(s.ssl, n);
        s.mutex.unlock();
        if (n > 0) return @intCast(n);
        switch (err) {
            c.SSL_ERROR_ZERO_RETURN => return 0,
            c.SSL_ERROR_WANT_READ => _ = net.waitFd(s.fd, net.WAIT_READ, -1),
            c.SSL_ERROR_WANT_WRITE => _ = net.waitFd(s.fd, net.WAIT_WRITE, WRITE_STALL_TIMEOUT_MS),
            // Peer closed the socket without a close_notify (or we shut it
            // down to interrupt this read): report as end-of-stream.
            c.SSL_ERROR_SYSCALL => return 0,
            else => return error.TlsReadError,
        }
    }
}

/// Non-blocking `sslRead` for event loops: returns decrypted bytes already
/// available, 0 on end-of-stream, or `error.WouldBlock` when OpenSSL needs
/// more input from the socket.  Callers must keep calling until WouldBlock —
/// OpenSSL may hold buffered plaintext that no socket readiness will report.
pub fn sslReadSome(conn: *SslConn, buf: []u8) !usize {
    const s = session(conn);
    if (buf.len == 0) return 0;
    const len: c_int = @intCast(@min(buf.len, std.math.maxInt(c_int)));
    s.mutex.lock();
    defer s.mutex.unlock();
    c.ERR_clear_error();
    const n = c.SSL_read(s.ssl, buf.ptr, len);
    if (n > 0) return @intCast(n);
    return switch (c.SSL_get_error(s.ssl, n)) {
        // WANT_WRITE (renegotiation) is resolved by the next blocking write.
        c.SSL_ERROR_WANT_READ, c.SSL_ERROR_WANT_WRITE => error.WouldBlock,
        c.SSL_ERROR_ZERO_RETURN, c.SSL_ERROR_SYSCALL => 0,
        else => error.TlsReadError,
    };
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
    const s = session(conn);
    var sent: usize = 0;
    while (sent < data.len) {
        const chunk = data[sent..];
        const len: c_int = @intCast(@min(chunk.len, std.math.maxInt(c_int)));
        s.mutex.lock();
        c.ERR_clear_error();
        const n = c.SSL_write(s.ssl, chunk.ptr, len);
        const err = if (n > 0) c.SSL_ERROR_NONE else c.SSL_get_error(s.ssl, n);
        s.mutex.unlock();
        if (n > 0) {
            sent += @intCast(n);
            continue;
        }
        switch (err) {
            c.SSL_ERROR_WANT_WRITE => {
                if (!net.waitFd(s.fd, net.WAIT_WRITE, WRITE_STALL_TIMEOUT_MS)) return error.TlsWriteTimeout;
            },
            c.SSL_ERROR_WANT_READ => {
                if (!net.waitFd(s.fd, net.WAIT_READ, WRITE_STALL_TIMEOUT_MS)) return error.TlsWriteTimeout;
            },
            else => return error.TlsWriteError,
        }
    }
}

/// Free the per-connection TLS session.
///
/// Must only be called once no other thread can be inside sslRead/sslWrite
/// for this connection (the owner guarantees that via reference counting).
/// When `graceful` is true a close_notify alert is attempted first; pass
/// false if the socket has already been shut down.
/// Does NOT free the SslCtx — that is owned by the ServerConnection or ClientConnection.
pub fn sslClose(conn: *SslConn, graceful: bool) void {
    const s = session(conn);
    if (graceful) {
        _ = c.SSL_shutdown(s.ssl);
    } else {
        c.SSL_set_quiet_shutdown(s.ssl, 1);
    }
    c.SSL_free(s.ssl);
    allocator.destroy(s);
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
