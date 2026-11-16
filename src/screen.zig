const rl = @import("raylib");
const main = @import("main.zig");
const std = @import("std");

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

    pub fn window(self: *Screen) !void {
        const width = self.width;
        const height = self.height;
        rl.initWindow(width, height, "my vm");
        defer rl.closeWindow();

        // Taille réelle du framebuffer utilisé par la texture
        const pixel_size: usize = @as(usize, @intCast(width)) * @as(usize, @intCast(height)) * 4;

        if (self.view.len < pixel_size) {
            return error.InvalidFramebufferSize;
        }

        const frame_buffer = self.view[0..].ptr;

        // Image qui pointe directement sur la RAM de ta VM
        const image: rl.Image = .{
            .data = @ptrCast(frame_buffer),
            .width = width,
            .height = height,
            .format = .uncompressed_r8g8b8a8,
            .mipmaps = 1,
        };

        // Upload initial et création de la texture GPU
        const texture = try rl.loadTextureFromImage(image);
        defer rl.unloadTexture(texture);

        rl.setTargetFPS(60);

        while (!rl.windowShouldClose()) {
            if (main.flag.load(.monotonic)) return;

            // Upload du framebuffer RAM vers la texture GPU
            rl.updateTexture(texture, @ptrCast(frame_buffer));

            rl.beginDrawing();

            rl.drawTexture(texture, 0, 0, .white);

            rl.endDrawing();
        }

        main.flag.store(true, .monotonic);
    }
};
