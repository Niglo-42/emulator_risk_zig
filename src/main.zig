const std = @import("std");
const elf = @import("elf.zig");
const launch = @import("fetch_and_decode.zig");
const Err = error{BinPathIsMissing};
const stdin = @import("stdin.zig");
const bus = @import("bus.zig");
var orig_termios: ?std.os.linux.termios = undefined;
pub var in: std.Io.File = undefined;
pub var io: std.process.Init = undefined;

pub fn main(init: std.process.Init) !void {
    io = init;
    in = std.Io.File.stdin();
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const opener = std.Io.Dir.cwd();
    if (args.len < 2) {
        return Err.BinPathIsMissing;
    }

    const file = try opener.openFile(init.io, args[1], .{});
    var debug = false;
    if (args.len == 3) {
        debug = true;
    }
    defer file.close(init.io);
    const stat = try file.stat(init.io);
    const size: u64 = stat.size;
    const buffer = try arena.alloc(u8, size);
    defer arena.free(buffer);
    _ = try file.readPositionalAll(init.io, buffer, 0);
    const elf_report = try elf.parse_elf(buffer);
    if (debug) {
        for (elf_report) |tup| {
            std.debug.print("text: {d}octs, bss: {d}octs\n", tup);
        }
    }
    orig_termios = try stdin.enableRawMode();
    if (orig_termios != null){defer stdin.disableRawMode(orig_termios.?);}
    try launch.fetch(4, debug);
    // return bus.regs[10];
}
