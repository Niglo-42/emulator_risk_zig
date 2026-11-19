pub var csr: [0x1000]u32 = @splat(0);
pub const privilege: u2 = 3;
const op = @import("op.zig");
const bus = @import("bus.zig");
const std = @import("std");

const Err = error{
    ReadConst,
    NeedMorePrivilege,
    RegZero,
};

const Config = enum(u12) {
    MISA = 0x301,
    mstatus = 0x300,
    mstatush = 0x310,
    mie = 0x304,
    mtvex = 0x305,
    mcounteren = 0x306,
    mscratch = 0x340,
    mepc = 0x341,
    mcause = 0x342,
    mtval = 0x343,
    mip = 0x344,

    mcycle = 0xb00,
    mcycleh = 0xb80,
    minstret = 0xb02,
    minstreth = 0xb82,
    cycle = 0xc00,
    cycleh = 0xc80,
    instret = 0xc02,
    instreth = 0xc82,
    time = 0xc01,
    timeh = 0xc81,
};

const MASK = enum(u32) {
    MISA = 0,
    mstatus = 0x300,
    mstatush = 0x310,
    mie = 0x304,
    mtvex = 0x305,
    mcounteren = 0x306,
    mscratch = 0x340,
    mepc = 0x341,
    mcause = 0x342,
    mtval = 0x343,
    mip = 0x344,

    mcycle = 0xb00,
    mcycleh = 0xb80,
    minstret = 0xb02,
    minstreth = 0xb82,
    cycle = 0xc00,
    cycleh = 0xc80,
    instret = 0xc02,
    instreth = 0xc82,
    time = 0xc01,
    timeh = 0xc81,
};

pub fn init_csr() void {
    csr[Config.MISA] = 0x40101101;
    // sur 4  reg
}

fn fn_csr(instr: op.INSTRUCTION.I, varianteI: bool) !struct { u32, u32, bool } {
    var write: bool = true;
    const src1_val = bus.regs[instr.rs1];
    const idx: u12 = if (varianteI) src1_val else @truncate(instr.get_imm());
    const droits: u2 = @truncate(idx >> 10);
    const required_privilege: u2 = @truncate(idx >> 8);
    const src_val = if (varianteI) instr.rs1 else src1_val;

    if (droits == 0b11) {
        std.debug.print("lecture seule !", .{});
        return Err.ReadConst;
    }
    if (required_privilege > bus.privilege) {
        std.debug.print("you need more privilege", .{});
        return Err.NeedMorePrivilege;
    }

    if (idx == Config.MISA) { // todo ajouter les adress speciale en lecture seule
        write = false;
    }
    if (instr.rd != 0) {
        bus.regs[instr.rd] = csr[idx];
    }
    return .{ idx, src_val, write };
}

pub fn csrrw(instr: op.INSTRUCTION.I) !void {
    const idx, const src_val, const write = try csr(instr, false);
    if (write) {
        csr[idx] = (src_val);
    }
}

pub fn csrrwi(instr: op.INSTRUCTION.I) !void {
    const idx, const src_val, const write = try csr(instr, true);
    if (write) {
        csr[idx] = (src_val);
    }
}

pub fn csrrs(instr: op.INSTRUCTION.I) !void {
    const idx, const src_val, const write = try csr(instr, false);
    if (write) {
        csr[idx] = csr[idx] | src_val;
    }
}

pub fn csrrsi(instr: op.INSTRUCTION.I) !void {
    const idx, const src_val, const write = try csr(instr, true);
    if (write) {
        csr[idx] = csr[idx] | src_val;
    }
}

pub fn csrrc(instr: op.INSTRUCTION.I) !void {
    const idx, const src_val, const write = try csr(instr, false);
    if (write) {
        csr[idx] = csr[idx] & ~(src_val);
    }
}

pub fn csrrci(instr: op.INSTRUCTION.I) !void {
    const idx, const src_val, const write = try csr(instr, true);
    if (write) {
        csr[idx] = csr[idx] & ~(src_val);
    }
}
// l'index d'un csr transporte des métadonnées
// si bit 11 allumé alors c'est une const
// bit 9 et 8 = (00: u, 01: s, 11:m) les privileges
// u = user et m = machine

// mvendorid 0xF11,
// marchid 0xF12,
// mimpid 0xF13 : 0, ce qui veut dire « non renseigné ».
// mhartid 0xF14 : 0, puisque tu as un seul cœur.

// commence à s'eloigner de bus donc faire un nouveau fichier csr
// config (description de la machine):
// misa 0x301 : l’architecture et les extensions présentes.
// Bits 31:30 = 01 pour 32 bits.
// Ensuite, un bit par lettre : A = bit 0, I = bit 8,
//  M = bit 12, S = bit 18, U = bit 20.
// Pour RV32IMA avec le mode U, ça donne 0x40101101.
//  N’active le bit A que quand A sera vraiment implémentée.
// Les écritures sont ignorées.
// mstatus 0x300 : l’état global. En M + U,
//  seuls trois champs existent :
// MIE, bit 3 : interruptions autorisées globalement ;
// MPIE, bit 7 : la valeur de MIE avant le trap ;
// MPP, bits 12:11 : le privilège avant le trap.
//  Seules les valeurs 00 et 11 sont légales ;
//  si on écrit 01 ou 10, ramène à une valeur légale.
// Tous les autres bits se lisent à 0 et ignorent
//  les écritures : c’est un masque d’écriture.

//TODO implémente les configs des 15 regs de csr
// ajoute aussi les 4 regs de cycle puis test.
// les instructions sont faites et branchées, et ça compile
// git push fait, tu en es à 1h de travail, à ajouter à cette
// deuxieme partie.
