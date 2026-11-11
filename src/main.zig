const std = @import("std");
const elf = @import("elf.zig");
const launch = @import("fetch_and_decode.zig");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const opener = std.Io.Dir.cwd();
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
    elf.parse_elf(buffer);
    try launch.fetch(4, debug);
}
