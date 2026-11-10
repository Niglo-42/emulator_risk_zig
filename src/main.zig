const std = @import("std");
const print = std.debug.print;
const def_reg = @import("data/define_regs.zig");
const elf = @import("elf.zig");
const sys = @import("syscall.zig");

pub var regs: [32]u32 = @splat(0);
pub var ram: [0x80000]u8 = undefined;
pub var pc: u32 = 0;
const _start_ = 0x1000;

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

fn op_load(instr: I) void {
    if (instr.rd == 0) {
        return;
    }
    const mask: u32 = switch (instr.func3) {
        0 => 0xffffff00, //lb
        1 => 0xffff0000, //lh
        else => 0x0,
    };
    const size: u32 = switch (instr.func3) {
        0, 4 => 1,
        1, 5 => 2,
        2 => 4,
        else => 4,
    };
    const addr = regs[instr.rs1] +% instr.get_imm();
    if (addr > ram.len or size > ram.len - addr) {
        print("LOAD OUT OF BOUNDS: 0x{x}\n", .{addr});
        return;
    }
    var data: u32 = 0;
    for (0..size) |i| {
        const shift: u5 = @truncate(i * 8);
        data |= @as(u32, ram[addr + i]) << shift;
    }
    const neg: u5 = @truncate(size * 8 - 1);
    if (instr.func3 > 1) // si unsigned
    {
        regs[instr.rd] = data;
    } else {
        if ((data >> neg) == 1) {
            regs[instr.rd] = mask | data;
        } else {
            regs[instr.rd] = data;
        }
    }
}

fn jal(instr: J) void {
    if (instr.rd != 0) {
        regs[instr.rd] = pc + 4;
    }
    pc = pc +% instr.get_imm();
}

fn jalr(instr: I) void {
    const ra: u32 = pc + 4;
    pc = (regs[instr.rs1] +% instr.get_imm()) & 0xfffffffe;
    if (instr.rd != 0) {
        regs[instr.rd] = ra;
    }
}

fn lui(instr: U) void {
    regs[instr.rd] = instr.get_imm();
}

fn auipc(instr: U) void {
    regs[instr.rd] = pc +% instr.get_imm();
}

fn op_S(instr: S) void {
    const size: u32 = switch (instr.func3) {
        0 => 1, // SB
        1 => 2, // SH
        2 => 4, // SW
        else => return,
    };

    const addr = regs[instr.rs1] +% instr.get_imm();
    const value = regs[instr.rs2];

    if (addr > ram.len or size > ram.len - addr) {
        print("STORE OUT OF BOUNDS: 0x{x}\n", .{addr});
        return;
    }

    for (0..size) |i| {
        const shift: u5 = @intCast(i * 8);
        ram[addr + i] = @truncate(value >> shift);
    }
}

fn op_B(instr: B) bool {
    switch (instr.func3) {
        0 => { // beq
            if (@as(i32, @bitCast(regs[instr.rs1])) == @as(i32, @bitCast(regs[instr.rs2]))) {
                pc = pc +% instr.get_imm();
                return true;
            }
        },
        1 => { // bne
            if (@as(i32, @bitCast(regs[instr.rs1])) != @as(i32, @bitCast(regs[instr.rs2]))) {
                pc = pc +% instr.get_imm();
                return true;
            }
        },
        4 => { //blt
            if (@as(i32, @bitCast(regs[instr.rs1])) < @as(i32, @bitCast(regs[instr.rs2]))) {
                pc = pc +% instr.get_imm();
                return true;
            }
        },
        5 => { //bge
            if (@as(i32, @bitCast(regs[instr.rs1])) >= @as(i32, @bitCast(regs[instr.rs2]))) {
                pc = pc +% instr.get_imm();
                return true;
            }
        },
        6 => { //bltu
            if (regs[instr.rs1] < regs[instr.rs2]) {
                pc = pc +% instr.get_imm();
                return true;
            }
        },
        7 => { //bgeu
            if (regs[instr.rs1] >= regs[instr.rs2]) {
                pc = pc +% instr.get_imm();
                return true;
            }
        },
        else => {
            print("branch not found", .{});
            return false;
        },
    }
    return false;
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
    const ai: i32 = @bitCast(a);
    const bi: i32 = @bitCast(b);
    if (ai < bi) {
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

    print("{X:0>4}: ", .{pc});
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

fn decode(instr: []const u8, init: std.process.Init, debug: bool) void {
    const instruction: INSTRUCTION = @bitCast(std.mem.readInt(u32, instr[0..4], std.builtin.Endian.little));
    if (debug) {
        disassembly(instruction);
    }

    var flag = false;
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
            flag = op_B(instruction.B);
        },
        0x23 => {
            op_S(instruction.S);
        },
        0x37 => {
            lui(instruction.U);
        },
        0x17 => {
            auipc(instruction.U);
        },
        0x6f => {
            flag = true;
            jal(instruction.J);
        },
        0x67 => {
            flag = true;
            jalr(instruction.I);
        },
        0x73 => {
            // system
            //ecall = 0x73 pure
            if (instruction.I.func3 == 0) {
                if (instruction.I.get_imm() == 0) {
                    const ram_addr: u32 = @truncate(@intFromPtr(&ram));
                    regs[def_reg.a7] = sys.translate(regs[def_reg.a7]) catch 1;
                    const flags: u16 = @truncate(regs[def_reg.a7]);
                    regs[def_reg.a7] = regs[def_reg.a7] & 0x3ff;
                    sys.read_flags(flags, &regs, ram_addr);
                    regs[def_reg.a0] = sys.syscall6(
                        regs[def_reg.a7],
                        regs[def_reg.a0],
                        regs[def_reg.a1],
                        regs[def_reg.a2],
                        regs[def_reg.a3],
                        regs[def_reg.a4],
                        regs[def_reg.a5],
                    );
                } else if (instruction.I.imm == 1) {
                    //ebreak 0x00100073
                }
            }
        },
        0xf => {
            //FENCE (opcode 0x0F, funct3 = 0)
            //Ses champs sont fm (bits 31:28),
            //pred (27:24) et succ (23:20).
            // Chaque ensemble pred/succ compose quatre bits :
            // I (entrée), O (sortie), R (lecture) et W (écriture),
            //avec I = bit 3 et W = bit 0
        },
        else => {
            print("OPCODE UNKNOWN \n", .{});
        },
    }
    if (flag == false) {
        pc += 4;
    }
    _ = init;
    regs[0] = 0;
}

fn fetch_mem(instr_size: u8, init: std.process.Init, debug: bool) void {
    while (true) {
        decode(ram[pc .. pc + instr_size], init, debug);
    }
    if (debug) {
        print_regs();
    }
}

pub fn main(init: std.process.Init) !void {
    @memset(ram[0..], 0);
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
    const n = try file.readPositionalAll(init.io, buffer, 0);
    if (n != size) {
        print("hoho problemo", .{});
    }
    elf.parse_elf(buffer, &regs);
    regs[def_reg.sp] = ram.len;
    fetch_mem(4, init, debug);
    print_ram();
}

// fn dump_buffer(buffer: []u8, size: usize) void {
//     for (0..size) |i| {
//         if (i != 0 and i & 3 == 0) {
//             print("\n", .{});
//         }
//         print("{X:0>2}", .{buffer[i]});
//     }
// }

fn print_ram() void {
    for (0..32) |byte| {
        if (byte != 0 and byte & 3 == 0) {
            print("\n", .{});
        }
        print("{X:0>2}", .{ram[0x400 + byte]});
    }
}
