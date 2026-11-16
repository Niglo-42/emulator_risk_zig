const rl = @import("raylib");
const main = @import("main.zig");
const std = @import("std");
const uart = @import("uart.zig");

const RGBA = enum {
    A,
    B,
    G,
    R,
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
                while (true) {
                    // pour toutes les char pressed dans les 16ms
                    const key: i32 = rl.getCharPressed();
                    if (key == 0) {
                        break;
                    }
                    try encode_utf8(key);
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

fn decode_utf8() void {}
// Le malentendu ATTENTION WARNING ACHTUNG !!!

// Ton commentaire final montre que tu attends 0x00 0x00 0xC3 0xA9 dans key,
//  comme si getCharPressed renvoyait déjà les octets UTF-8 et qu’il suffisait de les découper.
//   Ce n’est pas le cas : pour « é », key vaut 233, soit 0xE9.
//    C’est le numéro Unicode du caractère. 0xC3 0xA9 est ce que tu dois fabriquer.
fn encode_utf8(key: i32) !void {
    // Octet qui commence par 0 : un caractère ASCII complet, en un seul octet (0 à 127).
    // Octet qui commence par 110 : début d’un caractère de 2 octets.
    // Octet qui commence par 1110 : début d’un caractère de 3 octets.
    // Octet qui commence par 11110 : début d’un caractère de 4 octets (et pas 3 au maximum).
    // Octet qui commence par 10 : octet de continuation. Il porte 6 bits de données et n’est jamais un début.
    // écrit dans uart en encodage utf8 donc faudra aussi décoder pour write dans le terminal ou autre
    var byte: u5 = 3;
    while (true) {
        while (key >> (byte << 3) == 0) {
            byte -= 1;
        }
        var i: u3 = 7;
        var j: u3 = 0;
        while ((key >> (byte << 3)) >> i & 1 == 0) : (i -= 1) {
            const keyu: u32 = @bitCast(key);
            const x: u8 = @truncate((keyu >> ((byte - j) << 3)));
            _ = try uart.uart.host_write(x);
            j += 1;
            if (byte == 0) {
                return;
            }
        }
    } // 0x00 0x00 0xC3 0xA9 -> 1100.0011..1010.1001
}
