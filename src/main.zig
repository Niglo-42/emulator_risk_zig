const std = @import("std");
const elf = @import("elf.zig");
const launch = @import("fetch_and_decode.zig");
const Err = error{ BinPathIsMissing, UnknownOption };
const stdin = @import("stdin.zig");
const bus = @import("bus.zig");
var orig_termios: ?std.os.linux.termios = undefined;
pub var in: std.Io.File = undefined;
pub var io: std.process.Init = undefined;
const screen = @import("screen.zig");
const finisher = @import("finisher.zig");
pub var flag = std.atomic.Value(bool).init(false);

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
    var input_from_window = false;
    // headless : pas de fenêtre raylib (tests automatiques, plus tard Linux)
    var headless = false;
    // les options peuvent venir dans n'importe quel ordre après le fichier
    for (args[2..]) |arg| {
        if (std.ascii.eqlIgnoreCase(arg, "debug")) {
            debug = true;
        } else if (std.ascii.eqlIgnoreCase(arg, "input_from_window")) {
            input_from_window = true;
        } else if (std.ascii.eqlIgnoreCase(arg, "headless")) {
            headless = true;
        } else {
            std.debug.print("option inconnue : {s}\n", .{arg});
            return Err.UnknownOption;
        }
    }
    if (headless and input_from_window) {
        std.debug.print("headless et input_from_window sont incompatibles\n", .{});
        return Err.UnknownOption;
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
    defer stdin.disableRawMode(orig_termios);
    const alloc = std.heap.page_allocator;
    const spawn_conf = std.Thread.SpawnConfig{ .allocator = alloc };
    const thread = try std.Thread.spawn(spawn_conf, launch.fetch, .{ 4, debug, input_from_window });
    if (!headless) {
        try screen.screen.window(input_from_window);
    }
    thread.join();

    // Si le guest a demandé l'arrêt via le finisher, on sort avec son code.
    // std.process.exit ne lance pas les defer : on restaure le terminal avant.
    if (finisher.exit_code) |code| {
        stdin.disableRawMode(orig_termios);
        if (code == 0) {
            std.debug.print("PASS\n", .{});
        } else {
            std.debug.print("FAIL (code {d})\n", .{code});
        }
        std.process.exit(code);
    }
}
