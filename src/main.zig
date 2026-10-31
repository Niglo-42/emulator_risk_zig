const std = @import("std");
const print = std.debug.print;

var regs: [32]u32 = @splat(0);
var ram: [0x1000]u8 = @splat(0);
var pc: u32 = 0;

fn print_regs() void {
    for (regs, 0..regs.len) |reg, i| {
        print("R{d}: 0x{x:0>8}\n", .{ i, reg });
    }
    print("PC: 0x{x:0>8}\n", .{pc});
    print("\n", .{});
}

fn op_R(instr: R, f: fn (u32, u32) u32) void {
    regs[instr.rd] = f(regs[instr.rs1], regs[instr.rs2]);
}

fn op_I(instr: I, f: fn (u32, u32) u32) void {
    regs[instr.rd] = f(regs[instr.rs1], instr.get_imm());
}

fn fetch_ram(addr: u32) u32 {
    // ici je mets en big endian CAR cela preserve l'ordre des octets REEL
    // donc [12, 13, 14, 15] -> 12131415 et si je veux lb
    // je prends bien 121321415 & 0xff #camoulox
    // mais cela change mon abi donc je remet en little
    // # camoulox--
    const word: []u8 = ram[addr .. addr + 4];
    return std.mem.readInt(u32, word[0..4], std.builtin.Endian.little);
}

fn op_load(instr: I) void {
    if (instr.rd == 0) {
        return;
    }
    const mask: u32 = switch (instr.func3) {
        0 => 0xff,
        1 => 0xffff,
        2 => 0xffffffff,
        else => 4,
    };
    const data = fetch_ram(regs[instr.rs1] +% instr.get_imm()) & mask;
    print("apres fetch = {X}\n", .{data});
    print("REG = {X}\n", .{regs[instr.rd]});

    if (instr.func3 > 3) // si unsigned
    {
        regs[instr.rd] = data & mask;
    } else {
        if (instr.func3 == 0) {
            if (data >= 128) {
                regs[instr.rd] = 0xffffff00 | data;
            } else {
                regs[instr.rd] = data;
            }
        } else if (instr.func3 == 1) {
            if (data >= 0x8000) {
                regs[instr.rd] = 0xffff0000 | data;
            } else {
                regs[instr.rd] = data;
            }
        } else {
            regs[instr.rd] = data;
        }
    }
    print("REG = {X}\n", .{regs[instr.rd]});
}

fn op_S(instr: S) void {
    const mask: u5 = switch (instr.func3) {
        0 => 1,
        1 => 2,
        2 => 4,
        else => 4,
    };
    const addr = regs[instr.rs1] +% instr.get_imm();
    for (0..mask) |i| {
        const idx: u5 = @truncate(i);
        if (instr.rs2 == 0) {
            ram[addr + i] = 0;
        } else { //little,  adress forte byte forte
            ram[addr + mask - 1 - i] = @truncate(regs[instr.rs2] >> @as(u5, (mask - 1 - idx) * 8));
        }
    }
}

fn op_B(instr: B) void {
    switch (instr.func3) {
        0 => { // beq
            if (@as(i32, @bitCast(regs[instr.rs1])) == @as(i32, @bitCast(regs[instr.rs2]))) {
                pc += instr.get_imm();
            }
        },
        1 => { // bne
            if (@as(i32, @bitCast(regs[instr.rs1])) != @as(i32, @bitCast(regs[instr.rs2]))) {
                pc += instr.get_imm();
            }
        },
        4 => { //blt
            if (@as(i32, @bitCast(regs[instr.rs1])) < @as(i32, @bitCast(regs[instr.rs2]))) {
                pc += instr.get_imm();
            }
        },
        5 => { //bge
            if (@as(i32, @bitCast(regs[instr.rs1])) >= @as(i32, @bitCast(regs[instr.rs2]))) {
                pc += instr.get_imm();
            }
        },
        6 => { //bltu
            if (regs[instr.rs1] < regs[instr.rs2]) {
                pc += instr.get_imm();
            }
        },
        7 => { //bgeu
            if (regs[instr.rs1] >= regs[instr.rs2]) {
                pc += instr.get_imm();
            }
        },
        else => {
            print("branch not found", .{});
        },
    }
}

pub fn add(a: u32, b: u32) u32 {
    return a +% b;
}

pub fn sub(a: u32, b: u32) u32 {
    return a -% b;
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

fn disassembly(command: INSTRUCTION) void {
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
        else => "invalid type",
    };

    print("{X:0>4}: ", .{pc});
    if (command.R.opcode == 0x33) {
        print("{s} r{d}, r{d}, r{d} \n", .{ tag, command.R.rd, command.R.rs1, command.R.rs2 });
    } else if (command.R.opcode == 0x13) {
        print("{s} r{d}, r{d}, #{d} \n", .{ tag, command.I.rd, command.I.rs1, @as(i32, @bitCast(command.I.get_imm())) });
    } else if (command.R.opcode == 0x23) {
        print("{s} r{d}, r{d}, #{d} \n", .{ tag, command.S.rs1, command.S.rs2, @as(i32, @bitCast(command.S.get_imm())) });
    } else if (command.R.opcode == 0x63) {
        print("{s} r{d}, r{d}, #{d} \n", .{ tag, command.B.rs1, command.S.rs2, @as(i32, @bitCast(command.S.get_imm())) });
    } else if (command.R.opcode == 0x64 or command.R.opcode == 0x6f) {
        print("{s} r{d}, #{d} \n", .{ tag, command.J.rd, @as(i32, @bitCast(command.S.get_imm())) });
    } else if (command.R.opcode == 0x37 or command.R.opcode == 0x17) {
        print("{s} r{d}, #{d} \n", .{ tag, command.U.rd, @as(i32, @bitCast(command.S.get_imm())) });
    } else if (command.R.opcode == 0x3) {
        print("{s} r{d}, r{d}, #{d} \n", .{ tag, command.I.rd, command.I.rs1, @as(i32, @bitCast(command.S.get_imm())) });
    } else {
        print("unrecognized arg", .{});
    }
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
        var imm = B_imm{
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
        var imm = I_imm{ .imm0_11 = self.imm, .imm12_31 = @as(u20, 0) };
        if (self.imm >> 11 == 1) {
            imm.imm12_31 = std.math.maxInt(u20);
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
        var imm = S_imm{
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
        var imm = J_imm{
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

fn decode(instr: []const u8) void {
    const instruction: INSTRUCTION = @bitCast(std.mem.readInt(u32, instr[0..4], std.builtin.Endian.little));
    disassembly(instruction);
    switch (instruction.R.opcode) {
        0x33 => {
            switch (instruction.R.func3) {
                0 => {
                    if (instruction.R.func7 == 0x20) {
                        op_R(instruction.R, sub);
                    } else {
                        op_R(instruction.R, add);
                    }
                },
                1 => {
                    op_R(instruction.R, sll);
                },
                2 => {
                    op_R(instruction.R, slt);
                },
                3 => {
                    op_R(instruction.R, sltu);
                },
                4 => {
                    op_R(instruction.R, xor);
                },
                5 => {
                    if (instruction.R.func7 == 0x20) {
                        op_R(instruction.R, sra);
                    } else {
                        op_R(instruction.R, srl);
                    }
                },
                6 => {
                    op_R(instruction.R, or_);
                },
                7 => {
                    op_R(instruction.R, and_);
                },
            }
        },
        0x13 => {
            switch (instruction.I.func3) {
                0 => {
                    if (instruction.R.func7 == 0x20) {
                        op_I(instruction.I, add);
                    } else {
                        op_I(instruction.I, add);
                    }
                },
                1 => {
                    op_I(instruction.I, sll);
                },
                2 => {
                    op_I(instruction.I, slt);
                },
                3 => {
                    op_I(instruction.I, sltu);
                },
                4 => {
                    op_I(instruction.I, xor);
                },
                5 => {
                    if (instruction.R.func7 == 0x20) {
                        op_I(instruction.I, sra);
                    } else {
                        op_I(instruction.I, srl);
                    }
                },
                6 => {
                    op_I(instruction.I, or_);
                },
                7 => {
                    op_I(instruction.I, and_);
                },
            }
        },
        3 => {
            op_load(instruction.I);
        },
        0x63 => {
            //B
            op_B(instruction.B);
        },
        0x23 => {
            op_S(instruction.S);
        },
        0x37, 0x17 => {
            //U
            print("NOP", .{});
        },
        0x6f, 0x64 => {
            //J
            print("NOP", .{});
        },
        else => {
            print("OPCODE UNKNOWN \n", .{});
        },
    }
}

fn fetch_mem(buffer: []u8, instr_size: u8, buf_len: u64) void {
    while (pc < buf_len) : (pc += instr_size) {
        const end = @min(pc + instr_size, buf_len);
        const instr = buffer[pc..end];
        decode(instr);
    }
    print_regs();
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const opener = std.Io.Dir.cwd();
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
    fetch_mem(buffer, 4, size);
    print_ram();
}

fn print_ram() void {
    for (0..32) |byte| {
        if (byte != 0 and byte & 3 == 0) {
            print("\n", .{});
        }
        print("{X:0>2}", .{ram[0x400 + byte]});
    }
}
