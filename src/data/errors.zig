const def_reg = @import("define_regs.zig");
const std = @import("std");
const print = std.debug.print;

pub fn error_handeling(
    bad_value: u32,
    expected_val: u32,
    error_type: []const u8,
) void {
    print("error {s}: {X}, expected: {X}\n", .{ error_type, bad_value, expected_val });
}
