const std = @import("std");
const print = std.debug.print;

var regs: [32]u32 = @splat(0);
var pc: u32 = 0;

fn print_regs() void {
    for (regs, 0..regs.len) |reg, i| {
        print("R{d}: 0x{x:0>8}\n", .{ i, reg });
    }
    print("PC: 0x{x:0>8}\n", .{pc});
    print("\n", .{});
}

fn op_R(instr: INSTRUCTION.R, f: fn (u32, u32) u32) void {
    regs[instr.rd] = f(regs[instr.rs1], regs[instr.rs2]);
}

fn op_I(instr: INSTRUCTION.I, f: fn (u32, u32) u32) void {
    regs[instr.rd] = f(regs[instr.rs1], regs[instr.get_imm()]);
}

pub fn add(a: u32, b: u32) u32 {
    return a + b;
}

pub fn sub(a: u32, b: u32) u32 {
    return a - b;
}

pub fn xor(a: u32, b: u32) u32 {
    return a ^ b;
}

pub fn or_(a: u32, b: u32) u32 {
    return a | b;
}

pub fn and_(a: u32, b: u32) u32 {
    return a & b;
}

pub fn sll(a: u32, b: u32) u32 {
    const shift: u5 = @truncate(b);
    return a << shift;
}

pub fn srl(a: u32, b: u32) u32 {
    const shift: u5 = @truncate(b);
    return a >> shift;
}

pub fn slt(a: u32, b: u32) u32 {
    if (a < b) {
        return 1;
    }
    return 0;
}

pub fn sltu(a: u32, b: u32) u32 {
    if (a < b) {
        return 1;
    }
    return 0;
}

pub fn sra(a: u32, b: u32) u32 {
    const shift: u5 = @truncate(b);
    const res = a >> shift;
    if (a >> 31 == 1) {
        const mask = ~(@as(u32, 0xffffffff) >> shift);
        return res | mask;
    }
    return res;
}

pub fn not_(a: u32) u32 {
    return ~a;
}

const KIND = enum(u7) {
    R = 0x33,
    I = 0x13,
    B = 0x63,
    J = 0x6f,
    // SYSCALL = 0x73, DONC 0X70
    S = 0x23,
    // LOAD = 0x03, DONC 0
    U = 0x07,
};

const OP_LOAD = enum(u3) { LB = 0, LH = 1, LW = 2, LBU = 4, LHU = 5 };

const OP_STORE = enum(u3) { SB = 0, SH = 1, SW = 2 };

fn disassembly(command: u32, kind: KIND) void {
    // const opcode: u3 = @truncate(command >> 12);
    // const rd: u5 = @truncate(command >> 7);
    // const rs1: u5 = @truncate(command >> 15);
    // const op_enum: OP_R_I = @fromBackingInt(@intCast(opcode));
    // const instru = @tagName(op_enum);
    // print("{X:0>4}: ", .{pc});
    // if (kind == KIND.R) {
    //     const rs2: u5 = @truncate(command >> 20);
    //     print("{s} r{d}, r{d}, r{d} ", .{ instru, rd, rs1, rs2 });
    // } else if (kind == KIND.I) {
    //     const imm12: u12 = @truncate(command >> 20);
    //     const imm: i12 = @bitCast(imm12);
    //     print("{s} r{d}, r{d}, #{d} ", .{ instru, rd, rs1, imm });
    // }
    _ = command;
    _ = kind;
    return;
}

fn packing_data(instr: []const u8, little_endian: bool) u32 {
    var command: u32 = 0;
    if (little_endian) {
        for (0..4) |i| {
            var b: u32 = instr[i];
            const shift: u5 = @truncate(i * 8);
            b <<= shift;
            command |= b;
        }
    } else {
        for (instr) |byte| {
            command <<= 8;
            command |= byte;
        }
    }
    return command;
}

const INSTRUCTION = packed union { R: R, I: I, S: S, U: U, B: B, J: J };

const IMM = union { B: B_imm, I: I_imm, S: S_imm, U: U_imm, J: J_imm };

const B_imm = packed struct(u32) {
    imm0: u1,
    imm1_4: u4,
    imm5_10: u6,
    imm11: u1,
    imm12: u1,
    imm13_31: u19,
};

const S_imm = packed struct(u32) { imm0_4: u5, imm5_11: u7, imm12_31: u20 };

const I_imm = packed struct(u32) { imm0_11: u12, imm12_31: u20 };

const U_imm = packed struct(u32) { imm0_11: u12, imm12_31: u20 };

const J_imm = packed struct(u32) {
    imm0: u1,
    imm1_10: u10,
    imm11: u1,
    imm12_19: u8,
    imm20_31: u12,
};

const R = packed struct(u32) {
    opcode: u7,
    rd: u5,
    func3: u3,
    rs1: u5,
    rs2: u5,
    func7: u7,
};

const B = packed struct(u32) {
    opcode: u7,
    imm11: u1,
    imm1_4: u4,
    func3: u3,
    rs1: u5,
    rs2: u5,
    imm5_10: u6,
    imm12: u1,

    fn get_imm(self: B) u32 {
        const imm = B_imm{
            .imm0 = @as(u1, 0),
            .imm1_4 = self.imm1_4,
            .imm5_10 = self.imm5_10,
            .imm11 = self.imm11,
            .imm12 = self.imm12,
            .imm13_31 = @as(u19, 0),
        };
        if (self.imm12 == 1) {
            imm.imm13_31 = std.math.maxInt(u19);
        }
        return @bitCast(imm);
    }
};

const I = packed struct(u32) {
    opcode: u7,
    rd: u5,
    func3: u3,
    rs1: u5,
    imm: u12,

    fn get_imm(self: I) u32 {
        const imm = I_imm{ .imm0_11 = self.imm, .imm12_31 = @as(u20, 0) };
        if (self.imm >> 11 == 1) {
            imm.imm12_31 = std.math.maxInt(u19);
        }
        return @bitCast(imm);
    }
};

const S = packed struct(u32) {
    opcode: u7,
    imm0_4: u5,
    func3: u3,
    rs1: u5,
    rs2: u5,
    imm11_5: u7,

    fn get_imm(self: S) u32 {
        const imm = S_imm{
            .imm0 = @as(u1, 0),
            .imm0_4 = self.imm0_4,
            .imm5_11 = self.imm11_5,
            .imm12_31 = @as(u20, 0),
        };
        if (self.imm11_5 >> 6 == 1) {
            imm.imm12_31 = std.math.maxInt(u20);
        }
        return @bitCast(imm);
    }
};

const U = packed struct(u32) {
    opcode: u7,
    rd: u5,
    imm12_31: u20,

    fn get_imm(self: U) u32 {
        const imm = U_imm{
            .imm0_11 = @as(u12, 0),
            .imm12_31 = self.imm12_31,
        };
        return @bitCast(imm);
    }
};

const J = packed struct(u32) {
    opcode: u7,
    rd: u5,
    imm12_19: u8,
    imm20: u1,
    imm21_30: u10,
    imm31: u1,

    fn get_imm(self: J) u32 {
        const imm = J_imm{
            .imm0 = @as(u1, 0),
            .imm1_10 = self.imm21_30,
            .imm11 = self.imm20,
            .imm12_19 = self.imm12_19,
            .imm20_31 = @as(u12, 0),
        };
        if (self.imm31 == 1) {
            imm.imm20_31 = std.math.maxInt(u12);
        }
        return @bitCast(imm);
    }
};

fn decode(instr: []const u8, little_endian: bool) void {
    const instruction: INSTRUCTION = @bitCast(std.mem.readInt(u32, instr, little_endian));
    switch (instruction.R.opcode) {
        0x33 => {
            //R
            switch (instruction.R.func3) {
                0 => {
                    op_R(instruction, add);
                },
            }
        },
        0x13, 0x3, 0x67, 0x73, 0x0f => {
            //I
        },
        0x63 => {
            //B
        },
        0x23 => {
            //S
        },
        0x37, 0x17 => {
            //U
        },
        0x6f => {
            //J
        },
        else => {
            print("OPCODE UNKNOWN", .{});
        },
    }
}

fn fetch_mem(ram: []u8, buffer: []u8, instr_size: u8) void {
    const buf_len = buffer.len();
    while (pc < buf_len) : (pc += instr_size) {
        const end = @min(pc + instr_size, buf_len);
        const instr = buffer[pc..end];
        decode(instr, true);
    }
    print_regs();
    _ = ram[0];
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const opener = std.Io.Dir.cwd();
    var ram: [0x1000]u8 = undefined;
    @memset(&ram, 0);
    const file = try opener.openFile(init.io, args[1], .{});
    defer file.close(init.io);
    const stat = try file.stat(init.io);
    const size: u64 = stat.size;
    const buffer = try arena.alloc(u8, size);
    defer arena.free(buffer);
    const n = try file.readPositionalAll(init.io, buffer, 0);
    if (n != size) {
        print("hoho problemo", .{});
    }
    fetch_mem(&ram, buffer, 4);
}
