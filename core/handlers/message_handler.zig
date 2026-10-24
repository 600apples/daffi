const std = @import("std");
const enums = std.enums;
const net = std.net;
const serde = @import("../serde.zig");
const Message = serde.Message;
const MessageFlag = serde.MessageFlag;

pub fn MessageHandler(comptime T: type) type {
    return struct {
        ptr: *T,
        handlers_mapping: HandlersMapping,
        error_handler: *const fn (ctx: *T, conn: *T.ParentConnT, err: anyerror) anyerror!void,
        disconnection_handler: *const fn (ctx: *T, conn: *T.ParentConnT) anyerror!void,
        /// Called by serverLoop *after* it has finished examining (and possibly
        /// freeing) the current message.  Implementations should call
        /// TasksQueue.triggerWakeup() to notify the Python poller that one or
        /// more new messages are waiting.  No-op for handlers without a queue.
        wakeup_fn: *const fn (ctx: *T) void,

        const Self = @This();

        const flag_info = @typeInfo(MessageFlag).@"enum";
        pub const HandlersMapping = [flag_info.field_names.len]HandlerEntryFn;
        /// consumed: set to true by a handler that has transferred ownership of
        /// the message into a store or queue.  The caller must NOT touch the
        /// message after handle() returns when consumed == true.
        const HandlerEntryFn = *const fn (ctx: *T, conn: *T.ParentConnT, message: *Message, consumed: *bool) anyerror!void;

        pub fn createMapping(smapping: enums.EnumFieldStruct(MessageFlag, HandlerEntryFn, notSupported)) HandlersMapping {
            var mapping: HandlersMapping = undefined;
            inline for (flag_info.field_names, flag_info.field_values) |name, value| {
                mapping[value] = @field(smapping, name);
            }
            return mapping;
        }

        /// Dispatch message to the registered handler.
        /// `consumed` is set to true by the handler if ownership of the message
        /// was transferred to a store or queue; the caller must not free the
        /// message in that case (Python will call deinit() later).
        pub fn handle(self: Self, conn: *T.ParentConnT, message: *Message, consumed: *bool) !void {
            switch (message.getFlag()) {
                inline else => |fl| try self.handlers_mapping[@backingInt(fl)](self.ptr, conn, message, consumed),
            }
        }

        pub fn handleErr(self: Self, conn: *T.ParentConnT, err: anyerror) !void {
            try self.error_handler(self.ptr, conn, err);
        }

        pub fn handleDisconnect(self: Self, conn: *T.ParentConnT) !void {
            try self.disconnection_handler(self.ptr, conn);
        }

        /// Signal the Python poller that new messages may be available.
        /// Must be called *after* the caller is fully done with the message
        /// pointer so the Python poller cannot free it prematurely.
        pub fn triggerWakeup(self: Self) void {
            self.wakeup_fn(self.ptr);
        }

        fn notSupported(_: *T, _: *T.ParentConnT, message: *Message, _: *bool) !void {
            std.debug.print("message flag {any} not supported\n", .{message.getFlag()});
            return error.FlagNotSupported;
        }
    };
}
