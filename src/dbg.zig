const op = @import("op.zig");
const INSTRUCTION = op.INSTRUCTION;
const std = @import("std");
const print = std.debug.print;
const bus = @import("bus.zig");
const fetch = @import("fetch_and_decode.zig");
const regs = bus.regs;


pub fn print_regs() void {
    for (regs, 0..regs.len) |reg, i| {
        print("R{d}: 0x{x:0>8}\n", .{ i, reg });
    }
    print("PC: 0x{x:0>8}\n", .{fetch.pc });
    print("\n", .{});
}

pub fn disassembly(command: INSTRUCTION) void {
    const func7 = command.R.func7;
    const tag: []const u8 = switch (command.R.opcode) {
        0x33 => switch (func7) {
            0x20 => switch (command.R.func3) {
                0 => "sub",
                4 => "sra",
                else => "sub/sra_bug",
            },
            else => switch (command.R.func3) {
                0 => "sub",
                1 => "sll",
                2 => "slt",
                3 => "sltu",
                4 => "xor",
                5 => "srl",
                6 => "or",
                7 => "and",
            },
        },
        0x13 => switch (command.R.func3) { //i
            0 => "addi",
            1 => "slli",
            2 => "slti",
            3 => "sltiu",
            4 => "xori",
            5 => "srli",
            6 => "ori",
            7 => "andi",
        },
        0x23 => switch (command.R.func3) { //S
            0 => "sb",
            1 => "sh",
            2 => "sw",
            else => "invalid store",
        },
        0x3 => switch (command.R.func3) { //load I
            0 => "lb",
            1 => "lh",
            2 => "lw",
            4 => "lbu",
            5 => "lhu",
            else => "invalid load",
        },
        0x63 => switch (command.R.func3) {
            0 => "beq",
            1 => "bne",
            4 => "blt",
            5 => "bge",
            6 => "bltu",
            7 => "bgeu",
            else => "invalid branch",
        },
        0x67 => "jalr",
        0x6f => "jal",
        0x37 => "lui",
        0x17 => "auipc",
        0x73 => "ecall",
        else => "invalid type",
    };

    print("{X:0>4}: ", .{fetch.pc });
    if (command.R.opcode == 0x33) {
        print("{s} r{d}, r{d}, r{d} \n", .{ tag, command.R.rd, command.R.rs1, command.R.rs2 });
    } else if (command.R.opcode == 0x13) {
        print("{s} r{d}, r{d}, #{d} \n", .{ tag, command.I.rd, command.I.rs1, @as(i32, @bitCast(command.I.get_imm())) });
    } else if (command.R.opcode == 0x23) {
        print("{s} x{d}, {d}(x{d}) \n", .{ tag, command.S.rs2, @as(i32, @bitCast(command.S.get_imm())), command.S.rs1 });
    } else if (command.R.opcode == 0x63) {
        print("{s} r{d}, r{d}, #{d} \n", .{ tag, command.B.rs1, command.B.rs2, @as(i32, @bitCast(command.B.get_imm())) });
    } else if (command.R.opcode == 0x67 or command.R.opcode == 0x6f) {
        print("{s} r{d}, #{d} \n", .{ tag, command.J.rd, @as(i32, @bitCast(command.J.get_imm())) });
    } else if (command.R.opcode == 0x37 or command.R.opcode == 0x17) {
        print("{s} r{d}, #{d} \n", .{ tag, command.U.rd, @as(i32, @bitCast(command.U.get_imm())) });
    } else if (command.R.opcode == 0x3) {
        print("{s} x{d}, {d}(x{d}) \n", .{ tag, command.I.rd, @as(i32, @bitCast(command.I.get_imm())), command.I.rs1 });
    } else if (command.R.opcode == 0x73) {
        print("{s}\n", .{tag});
    } else {
        print("unrecognized arg", .{});
    }
}