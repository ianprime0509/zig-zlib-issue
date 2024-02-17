const std = @import("std");
const assert = std.debug.assert;

const first_object = @embedFile("first.obj");
const second_object = @embedFile("second.obj");

test "decompress" {
    var data_stream = std.io.fixedBufferStream(first_object ++ second_object);
    var data_reader: RewindableBufferedReader(@TypeOf(data_stream.reader()), .{
        .buffer_size = 4096,
        .max_rewind = 8,
    }) = .{ .unbuffered_reader = data_stream.reader() };

    var buf: [1024]u8 = undefined;
    {
        var decompressed = std.io.fixedBufferStream(&buf);
        var decompressor = std.compress.zlib.decompressor(data_reader.reader());
        var fifo = std.fifo.LinearFifo(u8, .{ .Static = 1024 }).init();
        try fifo.pump(decompressor.reader(), decompressed.writer());
        try std.testing.expectEqualStrings(
            \\tree 254b029bac4da1ef2c779044adc3c0fad85f8068
            \\parent 28ddaf81d9cd0a71b139d09b88ae5957c5a91f1d
            \\author Ian Johnson <ian@ianjohnson.dev> 1695580224 -0400
            \\committer Ian Johnson <ian@ianjohnson.dev> 1695580224 -0400
            \\
            \\commit 20
            \\
        , decompressed.getWritten());
        const unused_bytes = std.mem.alignForward(usize, decompressor.bits.nbits, 8) / 8;
        data_reader.rewind(unused_bytes) catch unreachable;
    }
    {
        var decompressed = std.io.fixedBufferStream(&buf);
        var decompressor = std.compress.zlib.decompressor(data_reader.reader());
        var fifo = std.fifo.LinearFifo(u8, .{ .Static = 1024 }).init();
        try fifo.pump(decompressor.reader(), decompressed.writer());
        try std.testing.expectEqualStrings(
            \\tree d71cfb798acac6507d07c311bc6dca2e1c1f3fca
            \\parent 1da9fdcf31b0342d1792cbfd8d6a8300eb21a1dc
            \\author Ian Johnson <ian@ianjohnson.dev> 1695580186 -0400
            \\committer Ian Johnson <ian@ianjohnson.dev> 1695580186 -0400
            \\
            \\commit 19
            \\
        , decompressed.getWritten());
    }
}

const RewindableBufferedReaderOptions = struct {
    buffer_size: usize,
    max_rewind: usize,
};

fn RewindableBufferedReader(comptime ReaderType: type, comptime options: RewindableBufferedReaderOptions) type {
    comptime assert(options.buffer_size > options.max_rewind);

    return struct {
        unbuffered_reader: ReaderType,
        buf: [options.buffer_size]u8 = undefined,
        start: usize = 0,
        end: usize = 0,

        pub const Error = ReaderType.Error;
        pub const Reader = std.io.Reader(*Self, Error, read);

        const Self = @This();

        pub fn read(self: *Self, dest: []u8) Error!usize {
            var dest_index: usize = 0;

            while (dest_index < dest.len) {
                const written = @min(dest.len - dest_index, self.end - self.start);
                @memcpy(dest[dest_index..][0..written], self.buf[self.start..][0..written]);
                if (written == 0) {
                    const n = try self.refill();
                    if (n == 0) {
                        return dest_index;
                    }
                }
                self.start += written;
                dest_index += written;
            }
            return dest.len;
        }

        fn refill(self: *Self) !usize {
            // Preserve up to max_rewind bytes of data in the buffer.
            const keep_bytes = @min(self.start, options.max_rewind);
            std.mem.copyBackwards(u8, self.buf[0..keep_bytes], self.buf[self.start..][0..keep_bytes]);
            self.start = keep_bytes;
            const n = try self.unbuffered_reader.read(self.buf[self.start..]);
            self.end = self.start + n;
            return n;
        }

        pub fn rewind(self: *Self, amount: usize) error{CannotRewind}!void {
            if (amount > self.start) return error.CannotRewind;
            self.start -= amount;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}
