const std = @import("std");
const bus = @import("bus.zig");
const fetch = @import("fetch_and_decode.zig");

const Err = error{
    BadByteNb,
};

pub fn _R(instr: R, f: fn (u32, u32) u32) void {
    bus.regs[instr.rd] = f(bus.regs[instr.rs1], bus.regs[instr.rs2]);
}

pub fn _I(instr: I, f: fn (u32, u32) u32) void {
    bus.regs[instr.rd] = f(bus.regs[instr.rs1], instr.get_imm());
}

pub fn _load(instr: I) !void {
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
        else => {return Err.BadByteNb;},
    };
    const addr = bus.regs[instr.rs1] +% instr.get_imm();
    const data: u32 = try bus.fetch_mem(addr, size);
    const neg: u5 = @truncate(size * 8 - 1);
    if (instr.func3 > 1) // si unsigned
    {
        bus.regs[instr.rd] = data;
    } else {
        if ((data >> neg) == 1) {
            bus.regs[instr.rd] = mask | data;
        } else {
            bus.regs[instr.rd] = data;
        }
    }
}

pub fn jal(instr: J) void {
    if (instr.rd != 0) {
        bus.regs[instr.rd] = fetch.pc + 4;
    }
    fetch.pc = fetch.pc +% instr.get_imm();
}

pub fn jalr(instr: I) void {
    const ra: u32 = fetch.pc + 4;
    fetch.pc = (bus.regs[instr.rs1] +% instr.get_imm()) & 0xfffffffe;
    if (instr.rd != 0) {
        bus.regs[instr.rd] = ra;
    }
}

pub fn lui(instr: U) void {
    bus.regs[instr.rd] = instr.get_imm();
}

pub fn auipc(instr: U) void {
    bus.regs[instr.rd] = fetch.pc +% instr.get_imm();
}

pub fn _S(instr: S) !void {
    const size: u32 = switch (instr.func3) {
        0 => 1, // SB
        1 => 2, // SH
        2 => 4, // SW
        else => return,
    };

    const addr = bus.regs[instr.rs1] +% instr.get_imm();
    const value = bus.regs[instr.rs2];
    try bus.store_mem(addr, size, value);
}

pub fn _B(instr: B) bool {
    switch (instr.func3) {
        0 => { // beq
            if (@as(i32, @bitCast(bus.regs[instr.rs1])) == @as(i32, @bitCast(bus.regs[instr.rs2]))) {
                fetch.pc = fetch.pc +% instr.get_imm();
                return true;
            }
        },
        1 => { // bne
            if (@as(i32, @bitCast(bus.regs[instr.rs1])) != @as(i32, @bitCast(bus.regs[instr.rs2]))) {
                fetch.pc = fetch.pc +% instr.get_imm();
                return true;
            }
        },
        4 => { //blt
            if (@as(i32, @bitCast(bus.regs[instr.rs1])) < @as(i32, @bitCast(bus.regs[instr.rs2]))) {
                fetch.pc = fetch.pc +% instr.get_imm();
                return true;
            }
        },
        5 => { //bge
            if (@as(i32, @bitCast(bus.regs[instr.rs1])) >= @as(i32, @bitCast(bus.regs[instr.rs2]))) {
                fetch.pc = fetch.pc +% instr.get_imm();
                return true;
            }
        },
        6 => { //bltu
            if (bus.regs[instr.rs1] < bus.regs[instr.rs2]) {
                fetch.pc = fetch.pc +% instr.get_imm();
                return true;
            }
        },
        7 => { //bgeu
            if (bus.regs[instr.rs1] >= bus.regs[instr.rs2]) {
                fetch.pc = fetch.pc +% instr.get_imm();
                return true;
            }
        },
        else => {
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

pub const INSTRUCTION = packed union { R: R, I: I, S: S, U: U, B: B, J: J };

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

    pub fn get_imm(self: B) u32 {
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

    pub fn get_imm(self: I) u32 {
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

    pub fn get_imm(self: S) u32 {
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

    pub fn get_imm(self: U) u32 {
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

    pub fn get_imm(self: J) u32 {
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
