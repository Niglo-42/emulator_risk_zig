const def_reg = @import("define_regs.zig");
const print = @import("std.debug.print");

pub fn error_handeling(bad_value: u32, expected_val: u32, regs: []u32) void {
    regs[def_reg.a0] = 1;
    print("error : {d}, expected: {d}", .{ bad_value, expected_val });
}
