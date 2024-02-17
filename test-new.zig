const std = @import("std");

const first_object = @embedFile("first.obj");
const second_object = @embedFile("second.obj");

test "decompress" {
    var data_stream = std.io.fixedBufferStream(first_object ++ second_object);

    var buf: [1024]u8 = undefined;
    {
        var decompressed = std.io.fixedBufferStream(&buf);
        var decompressor = std.compress.zlib.decompressor(data_stream.reader());
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
        // Reader should not read past the end of the compressed data
        try std.testing.expect(data_stream.pos == first_object.len);
    }
    {
        var decompressed = std.io.fixedBufferStream(&buf);
        var decompressor = std.compress.zlib.decompressor(data_stream.reader());
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
