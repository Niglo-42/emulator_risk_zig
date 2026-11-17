const rl = @import("raylib");
const main = @import("main.zig");
const std = @import("std");
const uart = @import("uart.zig");
const bus = @import("bus.zig");
const utf8 = @import("utf_8.zig");

const RGBA = enum {
    A,
    B,
    G,
    R,
};

const Err = error{
    BadDecodeUtf8,
};

pub var screen = Screen.init(864, 1536);

const Screen = struct {
    view: [0x1000000]u8, // dynamik ?
    width: i32,
    height: i32,

    pub fn init(h: i32, w: i32) Screen {
        if (h * w > 0x1000000) {} // 16 mo
        return Screen{
            .view = @splat(0),
            .width = w,
            .height = h,
        };
    }

    pub fn window(self: *Screen, input_mode: bool) !void {
        const width = self.width;
        const height = self.height;
        rl.initWindow(width, height, "my vm");
        defer rl.closeWindow();
        const pixel_size: usize = @as(usize, @intCast(width)) * @as(usize, @intCast(height)) * 4;
        if (self.view.len < pixel_size) {
            return error.InvalidFramebufferSize;
        }
        const frame_buffer = self.view[0..].ptr;
        const image: rl.Image = .{
            .data = @ptrCast(frame_buffer),
            .width = width,
            .height = height,
            .format = .uncompressed_r8g8b8a8,
            .mipmaps = 1,
        };
        const texture = try rl.loadTextureFromImage(image);
        defer rl.unloadTexture(texture);
        rl.setTargetFPS(60);

        while (!rl.windowShouldClose()) {
            if (main.flag.load(.monotonic)) return;

            rl.updateTexture(texture, @ptrCast(frame_buffer));
            if (input_mode == true) {
                var buf: [4]u8 = undefined;
                while (true) {
                    // pour toutes les char pressed dans les 16ms
                    const key: i32 = rl.getCharPressed();
                    if (key == 0) {
                        break;
                    }
                    @memset(&buf, 0);
                    const byte2read = utf8.encode_utf8(key, &buf);
                    for (buf[0..byte2read]) |byte| {
                        _ = try uart.uart.host_write(byte);
                    }
                }
            }

            rl.beginDrawing();

            rl.drawTexture(texture, 0, 0, .white);
            // rl.drawText();
            rl.endDrawing();
        }

        main.flag.store(true, .monotonic);
    }
};

test "encoding utf8 little endian" {
    var buf: [4]u8 = undefined;

    // 1 byte: ASCII boundaries
    {
        const n = utf8.encode_utf8(0x00, &buf);
        try std.testing.expectEqual(@as(usize, 1), n);
        try std.testing.expectEqualSlices(u8, &.{0x00}, buf[0..n]);

        const n2 = utf8.encode_utf8(0x7F, &buf);
        try std.testing.expectEqual(@as(usize, 1), n2);
        try std.testing.expectEqualSlices(u8, &.{0x7F}, buf[0..n2]);
    }

    // 2 bytes: 0x80 - 0x7FF
    {
        const n = utf8.encode_utf8(0x80, &buf);
        try std.testing.expectEqual(@as(usize, 2), n);
        try std.testing.expectEqualSlices(u8, &.{ 0x80, 0xC2 }, buf[0..n]);

        const n2 = utf8.encode_utf8(0x7FF, &buf);
        try std.testing.expectEqual(@as(usize, 2), n2);
        try std.testing.expectEqualSlices(u8, &.{ 0xBF, 0xDF }, buf[0..n2]);
    }

    // 3 bytes: 0x800 - 0xFFFF
    {
        const n = utf8.encode_utf8(0x800, &buf);
        try std.testing.expectEqual(@as(usize, 3), n);
        try std.testing.expectEqualSlices(u8, &.{ 0x80, 0xA0, 0xE0 }, buf[0..n]);

        const n2 = utf8.encode_utf8(0xFFFF, &buf);
        try std.testing.expectEqual(@as(usize, 3), n2);
        try std.testing.expectEqualSlices(u8, &.{ 0xBF, 0xBF, 0xEF }, buf[0..n2]);
    }

    // 4 bytes: 0x10000 - 0x10FFFF
    {
        const n = utf8.encode_utf8(0x10000, &buf);
        try std.testing.expectEqual(@as(usize, 4), n);
        try std.testing.expectEqualSlices(u8, &.{ 0x80, 0x80, 0x90, 0xF0 }, buf[0..n]);

        const n2 = utf8.encode_utf8(0x10FFFF, &buf);
        try std.testing.expectEqual(@as(usize, 4), n2);
        try std.testing.expectEqualSlices(u8, &.{ 0xBF, 0xBF, 0x8F, 0xF4 }, buf[0..n2]);
    }

    // Real-world characters
    {
        // é U+00E9
        const n = utf8.encode_utf8(0xE9, &buf);
        try std.testing.expectEqual(@as(usize, 2), n);
        try std.testing.expectEqualSlices(u8, &.{ 0xA9, 0xC3 }, buf[0..n]);

        // € U+20AC
        const n2 = utf8.encode_utf8(0x20AC, &buf);
        try std.testing.expectEqual(@as(usize, 3), n2);
        try std.testing.expectEqualSlices(u8, &.{ 0xAC, 0x82, 0xE2 }, buf[0..n2]);

        // 😀 U+1F600
        const n3 = utf8.encode_utf8(0x1F600, &buf);
        try std.testing.expectEqual(@as(usize, 4), n3);
        try std.testing.expectEqualSlices(u8, &.{ 0x80, 0x98, 0x9F, 0xF0 }, buf[0..n3]);
    }

    // Invalid Unicode: surrogate range
    {
        const n = utf8.encode_utf8(0xD800, &buf);
        try std.testing.expectEqual(@as(usize, 0), n);

        const n2 = utf8.encode_utf8(0xDFFF, &buf);
        try std.testing.expectEqual(@as(usize, 0), n2);
    }

    // Invalid Unicode: beyond Unicode maximum
    {
        const n = utf8.encode_utf8(0x110000, &buf);
        try std.testing.expectEqual(@as(usize, 0), n);
    }
}
