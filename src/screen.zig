const rl = @import("raylib");

const RGBA = enum {
    A,
    B,
    G,
    R,
};

pub var screen = Screen.init(1536, 864);

const Screen = struct {
    view: [0x1000000]u8, // dynamik ?
    width: u32,
    height: u32,

    pub fn init(h: u32, w: u32) Screen {
        if (h * w > 0x1000000) // 16 mo
        return Screen{
            .view = @splat(0),
            .width = w,
            .height = h,
        };
    }

    pub fn window(self: Screen) anyerror!void {
    rl.initWindow(self.width, self.height, "my vm");
    defer rl.closeWindow(); // Close window and OpenGL context
    rl.setTargetFPS(60);
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.white);
        rl.drawText("Congrats! You created your first window!", 190, 200, 20, .light_gray);
    }
}
};


