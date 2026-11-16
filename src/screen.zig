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
                var buf: [5]u8 = undefined;
                while (true) {
                    // pour toutes les char pressed dans les 16ms
                    const key: i32 = rl.getCharPressed();
                    if (key == 0) {
                        break;
                    }
                    @memset(&buf, 0);
                    _ = utf8.encode_utf8(key, &buf);
                    var i: usize = 0;
                    while (buf[i] != 0) : (i += 1) {
                        _ = try uart.uart.host_write(buf[i]);
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

fn count_leading1(byte: u8) u3 {
    // ret the number of 1's -1 (the 0) - 1 cause we already read a byte
    // to decode the others
    // finally we count the number of byte we still have to parse !
    var res: u3 = 0;
    while ((byte >> (7 - res)) & 1 == 1) {
        res += 1;
    }
    if (res == 0) {
        return res;
    }
    return res - 1;
}

fn interprete_utf8() !void {
    // Octet qui commence par 0 : un caractère ASCII complet, en un seul octet (0 à 127).
    // Octet qui commence par 110 : début d’un caractère de 2 octets.
    // Octet qui commence par 1110 : début d’un caractère de 3 octets.
    // Octet qui commence par 11110 : début d’un caractère de 4 octets (et pas 3 au maximum).
    // Octet qui commence par 10 : octet de continuation. Il porte 6 bits de données et n’est jamais un début.
    // écrit dans uart en encodage utf8 donc faudra aussi décoder pour write dans le terminal ou autre
    var buf: [4]u8 = undefined;
    while (true) {
        const byte = uart.uart.guest_read();
        if (byte.? == null) {
            return;
        }
        const byte2read = count_leading1(byte);
        buf[0] = byte;
        for (0..byte2read) |i| {
            const b = uart.uart.guest_read();
            if (b.? == null or b >> 6 != 0b10) {
                return Err.BadDecodeUtf8;
            }
            buf[i + 1] = b;
        }
        uart.uart.setter(0, &buf[0..byte2read + 1]);
    }
}

test "encoding utf8" {
    var buf: [4]u8 = undefined;
    @memset(&buf, 0);
    const n = utf8.encode_utf8(233, &buf);
    var t: [2]u8 = undefined;
    t[0] = 0xa9;
    t[1] = 0xc3;
    for (0..n) |i| {
        try std.testing.expectEqual(t[i], buf[i]);
    }
    
}