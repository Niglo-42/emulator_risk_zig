const std = @import("std");
const bus = @import("bus.zig");
const fetch = @import("fetch_and_decode.zig");
const csr_ = @import("csr.zig");
const trap = @import("trap.zig");
const reservation = @import("reservation.zig");
const Err = error{
    BadByteNb,
    ReadConst,
    NeedMorePrivilege,
    RegZero,
};

pub fn _R(instr: R, f: fn (u32, u32) u32) void {
    bus.regs[instr.rd] = f(bus.regs[instr.rs1], bus.regs[instr.rs2]);
}

pub fn _I(instr: I, f: fn (u32, u32) u32) void {
    bus.regs[instr.rd] = f(bus.regs[instr.rs1], instr.get_imm());
}

pub fn _load(instr: I) !void {
    const mask: u32 = switch (instr.func3) {
        0 => 0xffffff00, //lb
        1 => 0xffff0000, //lh
        else => 0x0,
    };
    const size: u32 = switch (instr.func3) {
        0, 4 => 1,
        1, 5 => 2,
        2 => 4,
        else => {
            return trap.Fault.IllegalInstruction;
        },
    };
    const addr = bus.regs[instr.rs1] +% instr.get_imm();
    // une adresse hors du bus n'arrête plus l'émulateur : c'est une faute
    // de lecture pour le guest, avec l'adresse fautive dans mtval
    const data: u32 = bus.fetch_mem(addr, size) catch {
        trap.pending_tval = addr;
        return trap.Fault.LoadAccessFault;
    };
    const neg: u5 = @truncate(size * 8 - 1);
    if (instr.rd != 0) {
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
}

// Sans l'extension C, une instruction est toujours à une adresse multiple
// de 4. Un saut vers une autre adresse est une faute sur le SAUT lui-même :
// rd et pc ne changent pas, la cible va dans mtval.
fn check_jump_target(target: u32) trap.Fault!void {
    if (target & 3 != 0) {
        trap.pending_tval = target;
        return trap.Fault.InstructionMisaligned;
    }
}

pub fn jal(instr: J) trap.Fault!void {
    const target = fetch.pc +% instr.get_imm();
    try check_jump_target(target);
    if (instr.rd != 0) {
        bus.regs[instr.rd] = fetch.pc +% 4;
    }
    fetch.pc = target;
}

pub fn jalr(instr: I) trap.Fault!void {
    // rs1 est lu AVANT d'écrire rd (rd peut être == rs1)
    const target = (bus.regs[instr.rs1] +% instr.get_imm()) & 0xfffffffe;
    try check_jump_target(target);
    if (instr.rd != 0) {
        bus.regs[instr.rd] = fetch.pc +% 4;
    }
    fetch.pc = target;
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
        else => return trap.Fault.IllegalInstruction, // avant : ignoré en silence
    };

    const addr = bus.regs[instr.rs1] +% instr.get_imm();
    const value = bus.regs[instr.rs2];
    bus.store_mem(addr, size, value) catch {
        trap.pending_tval = addr;
        return trap.Fault.StoreAccessFault;
    };
}

// Renvoie true si le branchement est pris (le pc a déjà été mis à jour).
pub fn _B(instr: B) trap.Fault!bool {
    const taken = switch (instr.func3) {
        0 => if (@as(i32, @bitCast(bus.regs[instr.rs1])) == @as(i32, @bitCast(bus.regs[instr.rs2]))) true else false,
        1 => if (@as(i32, @bitCast(bus.regs[instr.rs1])) != @as(i32, @bitCast(bus.regs[instr.rs2]))) true else false,
        4 => if (@as(i32, @bitCast(bus.regs[instr.rs1])) < @as(i32, @bitCast(bus.regs[instr.rs2]))) true else false,
        5 => if (@as(i32, @bitCast(bus.regs[instr.rs1])) >= @as(i32, @bitCast(bus.regs[instr.rs2]))) true else false,
        6 => if (bus.regs[instr.rs1] < bus.regs[instr.rs2]) true else false,
        7 => if (bus.regs[instr.rs1] >= bus.regs[instr.rs2]) true else false,
        else => {
            return trap.Fault.IllegalInstruction;
        },
    };
    if (taken) {
        const target = fetch.pc +% instr.get_imm();
        try check_jump_target(target);
        fetch.pc = target;
    }
    return if (taken) false else true;
}

// ---------------------------------------------------------------------------
// Extension A (opcode 0x2F, funct3 = 010 pour .w)
// funct5 = bits 31:27 (les 5 bits hauts de func7) choisit l'opération.
// Les bits 26 (aq) et 25 (rl) règlent l'ordre mémoire entre plusieurs
// cœurs : avec un seul cœur, on les ignore.
//
// Pourquoi c'est atomique sans verrou : une instruction s'exécute en
// entier dans un seul appel à decode, et les interruptions ne seront
// prises qu'ENTRE deux instructions (dans la boucle fetch). Rien ne peut
// donc s'intercaler entre la lecture et l'écriture d'un AMO.
// ---------------------------------------------------------------------------
const AMO_LR: u5 = 0b00010;
const AMO_SC: u5 = 0b00011;
const AMO_SWAP: u5 = 0b00001;
const AMO_ADD: u5 = 0b00000;
const AMO_XOR: u5 = 0b00100;
const AMO_AND: u5 = 0b01100;
const AMO_OR: u5 = 0b01000;
const AMO_MIN: u5 = 0b10000;
const AMO_MAX: u5 = 0b10100;
const AMO_MINU: u5 = 0b11000;
const AMO_MAXU: u5 = 0b11100;

pub fn _amo(instr: R) trap.Fault!void {
    if (instr.func3 != 2) {
        return trap.Fault.IllegalInstruction; // seulement .w en RV32
    }
    const funct5: u5 = @truncate(instr.func7 >> 2);
    // on lit les sources AVANT toute écriture (rd peut être == rs1 ou rs2)
    const addr = bus.regs[instr.rs1];
    const src = bus.regs[instr.rs2];

    // contrairement aux load/store normaux, l'alignement est obligatoire
    if (addr & 3 != 0) {
        trap.pending_tval = addr;
        if (funct5 == AMO_LR) {
            return trap.Fault.LoadMisaligned;
        }
        return trap.Fault.StoreMisaligned;
    }

    if (funct5 == AMO_LR) {
        if (instr.rs2 != 0) {
            return trap.Fault.IllegalInstruction;
        }
        const value = bus.fetch_mem(addr, 4) catch {
            trap.pending_tval = addr;
            return trap.Fault.LoadAccessFault;
        };
        reservation.reserve(addr);
        if (instr.rd != 0) {
            bus.regs[instr.rd] = value;
        }
        return;
    }

    if (funct5 == AMO_SC) {
        var result: u32 = 1; // non nul = échec
        if (reservation.check_and_consume(addr)) {
            bus.store_mem(addr, 4, src) catch {
                trap.pending_tval = addr;
                return trap.Fault.StoreAccessFault;
            };
            result = 0; // succès
        }
        if (instr.rd != 0) {
            bus.regs[instr.rd] = result;
        }
        return;
    }

    // Les 9 AMO. Une faute, même pendant la LECTURE, est signalée comme
    // une faute de store (mcause 7).
    const old = bus.fetch_mem(addr, 4) catch {
        trap.pending_tval = addr;
        return trap.Fault.StoreAccessFault;
    };
    var new: u32 = 0;
    switch (funct5) {
        AMO_SWAP => new = src,
        AMO_ADD => new = old +% src,
        AMO_XOR => new = old ^ src,
        AMO_AND => new = old & src,
        AMO_OR => new = old | src,
        AMO_MIN => {
            if (@as(i32, @bitCast(old)) < @as(i32, @bitCast(src))) new = old else new = src;
        },
        AMO_MAX => {
            if (@as(i32, @bitCast(old)) > @as(i32, @bitCast(src))) new = old else new = src;
        },
        AMO_MINU => {
            if (old < src) new = old else new = src;
        },
        AMO_MAXU => {
            if (old > src) new = old else new = src;
        },
        else => return trap.Fault.IllegalInstruction,
    }
    bus.store_mem(addr, 4, new) catch {
        trap.pending_tval = addr;
        return trap.Fault.StoreAccessFault;
    };
    if (instr.rd != 0) {
        bus.regs[instr.rd] = old;
    }
}

pub fn mul(a: u32, b: u32) u32 {
    return @mulWithOverflow(a, b)[0];
}

pub fn mulh(a: u32, b: u32) u32 {
    const ai: i32 = @bitCast(a);
    const bi: i32 = @bitCast(b);
    const product: i64 = std.math.mulWide(i32, ai, bi);
    const res: u64 = @bitCast(product);
    return @truncate(res >> 32);
}

pub fn mulhu(a: u32, b: u32) u32 {
    const product: u64 = std.math.mulWide(u32, a, b);
    return @truncate(product >> 32);
}

pub fn mulhsu(rs1: u32, rs2: u32) u32 {
    const a: i32 = @bitCast(rs1);
    const b: u32 = rs2;
    const product = @as(i64, a) * @as(i64, b);
    return @truncate(@as(u64, @bitCast(product)) >> 32);
}

pub fn div(a: u32, b: u32) u32 {
    if (b == 0) {
        return std.math.maxInt(u32);
    }
    const ai: i32 = @bitCast(a);
    const bi: i32 = @bitCast(b);
    if (ai == std.math.minInt(i32) and bi == -1) {
        return a;
    }
    return @bitCast(@divTrunc(ai, bi));
}

pub fn divu(a: u32, b: u32) u32 {
    if (b == 0) {
        return std.math.maxInt(u32);
    }
    return @divTrunc(a, b);
}

pub fn rem(a: u32, b: u32) u32 {
    if (b == 0) {
        return a;
    }
    const ai: i32 = @bitCast(a);
    const bi: i32 = @bitCast(b);
    if (ai == std.math.minInt(i32) and bi == -1) {
        return 0;
    }
    return @bitCast(@rem(ai, bi));
}

pub fn remu(a: u32, b: u32) u32 {
    if (b == 0) {
        return a;
    }
    return @rem(a, b);
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

pub const R = packed struct(u32) {
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

pub const I = packed struct(u32) {
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

test "RISC-V signed division overflow" {
    const min = @as(u32, 0x80000000);
    const minus_one = @as(u32, 0xFFFFFFFF);

    try std.testing.expectEqual(min, div(min, minus_one));
    try std.testing.expectEqual(@as(u32, 0), rem(min, minus_one));
}

test "RISC-V division by zero" {
    try std.testing.expectEqual(
        std.math.maxInt(u32),
        div(123, 0),
    );

    try std.testing.expectEqual(
        @as(u32, 123),
        rem(123, 0),
    );
}
