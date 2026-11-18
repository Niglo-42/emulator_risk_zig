const std = @import("std");
const uart = @import("uart.zig");
const linux = std.os.linux;
const posix = std.posix;
const STDOUT_FILENO = posix.STDOUT_FILENO;
const STDIN_FILENO = posix.STDIN_FILENO;
const main = @import("main.zig");

const Err = error {
    Fail2Read,
    NotaTerminal,
};

pub fn enableRawMode() !?linux.termios {
    if (try main.in.isTty(main.io.io) == true) {
        const orig_termios = try posix.tcgetattr(STDIN_FILENO);
        var termios = orig_termios;
        termios.lflag.ECHO = false;
        termios.lflag.ICANON = false;
        termios.iflag.IXON = false; // disable Ctrl-S and Ctrl-Q signals
        termios.lflag.IEXTEN = false; // disable Ctrl-V
        // termios.oflag.OPOST = false; // disable the famous \r before the \n

        termios.iflag.INPCK = false; // disable parity checking (obsolete?)
        termios.iflag.ISTRIP = false; // disable stripping of 8th bit
        termios.cflag.CSIZE = .CS8; // set character size to 8 bits
        // Set read timeouts
        termios.cc[@intFromEnum(linux.V.MIN)] = 0; // Return immediately when any bytes are available
        termios.cc[@intFromEnum(linux.V.TIME)] = 0; // Wait up to 0 seconds for input
        posix.tcsetattr(STDIN_FILENO, .FLUSH, termios) catch @panic("Disabling raw mode failed!");
        return orig_termios;
    } else {
        return null;
    }
}

/// Disable terminal raw mode by restoring the saved configuration.
pub fn disableRawMode(orig_termios: ?linux.termios) void {
    if (orig_termios) |termios| {
        posix.tcsetattr(STDIN_FILENO, .FLUSH, termios) catch @panic("Disabling raw mode failed!");
    }
}

pub fn serve_the_world() !void {
    var buf: [4]u8 = undefined;
    const n = linux.read(0, &buf, 4);
    if (n > 4) {
        return Err.Fail2Read;
    }
    const nb: u3 = @min(n, 4);
    for (0..nb) |i| {
        const x = uart.uart.host_write(buf[i], nb) catch -1;
        if (x == -1) {
            std.debug.print("queue full", .{});
        }
    }
}