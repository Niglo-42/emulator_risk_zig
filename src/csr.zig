// CSR = Control and Status Registers.
// Ce sont des registres INTERNES au CPU (comme x0..x31), avec leur propre
// espace d'adressage de 12 bits. Ils ne passent PAS par le bus : seules les
// 6 instructions Zicsr (csrrw, csrrs, csrrc + variantes immédiates) y accèdent.
//
// Le numéro d'un CSR porte ses droits :
//   bits 11:10 == 0b11  -> lecture seule
//   bits 9:8            -> privilège minimum (00 = U, 01 = S, 11 = M)

const std = @import("std");
const op = @import("op.zig");
const bus = @import("bus.zig");

pub const Err = error{IllegalInstruction};

// ---------------------------------------------------------------------------
// État caché du CPU : le niveau de privilège courant.
// Ce n'est PAS un CSR : aucune instruction ne peut le lire directement.
// Au reset on démarre en mode machine.
// ---------------------------------------------------------------------------
pub const USER: u2 = 0;
pub const MACHINE: u2 = 3;
pub var privilege: u2 = MACHINE;

// ---------------------------------------------------------------------------
// Compteurs 64 bits. Sur RV32 on les lit/écrit par moitiés (mcycle / mcycleh).
// Ils sont incrémentés dans la boucle fetch, après chaque instruction.
// ---------------------------------------------------------------------------
pub var cycle_counter: u64 = 0;
pub var instret_counter: u64 = 0;

// Stockage des CSR qui sont de "simples registres" (mstatus, mepc, ...).
// Indexé par le numéro du CSR.
var storage: [0x1000]u32 = @splat(0);

// RV32 (bits 31:30 = 01) + I (bit 8) + M (bit 12) + U (bit 20).
// Quand l'extension A sera implémentée, ajoute le bit 0 -> 0x40101101.
pub const MISA_VALUE: u32 = (1 << 30) | (1 << 8) | (1 << 12) | (1 << 20);

// Bits de mstatus (utilisés par les traps à l'étape suivante)
pub const MSTATUS_MIE: u32 = 1 << 3;
pub const MSTATUS_MPIE: u32 = 1 << 7;
pub const MSTATUS_MPP: u32 = 0b11 << 11;

// Bits de mie / mip
pub const MIP_MSIP: u32 = 1 << 3; // interruption logicielle
pub const MIP_MTIP: u32 = 1 << 7; // interruption timer
pub const MIP_MEIP: u32 = 1 << 11; // interruption externe

// Tous les CSR qui existent sur cette machine.
// Un numéro qui n'est pas dans cet enum = CSR inexistant = instruction illégale.
pub const Config = enum(u12) {
    // identification (lecture seule)
    mvendorid = 0xf11,
    marchid = 0xf12,
    mimpid = 0xf13,
    mhartid = 0xf14,

    // configuration
    mstatus = 0x300,
    misa = 0x301,
    mie = 0x304,
    mtvec = 0x305,
    mcounteren = 0x306,
    mstatush = 0x310,

    // gestion des traps
    mscratch = 0x340,
    mepc = 0x341,
    mcause = 0x342,
    mtval = 0x343,
    mip = 0x344,

    // protection mémoire : 0 entrée implémentée (masque à 0)
    pmpcfg0 = 0x3a0,
    pmpaddr0 = 0x3b0,

    // compteurs machine (lecture/écriture en mode M)
    mcycle = 0xb00,
    minstret = 0xb02,
    mcycleh = 0xb80,
    minstreth = 0xb82,

    // copies en lecture seule pour le mode U
    cycle = 0xc00,
    time = 0xc01,
    instret = 0xc02,
    cycleh = 0xc80,
    timeh = 0xc81,
    instreth = 0xc82,
};

// Les 6 instructions Zicsr.
pub const CsrOp = enum { rw, rs, rc, rwi, rsi, rci };

// ---------------------------------------------------------------------------
// Masque d'écriture : les bits qu'une INSTRUCTION CSR a le droit de modifier.
// Le switch est exhaustif : si tu ajoutes un CSR à Config sans lui donner
// de masque, le compilateur refuse de compiler.
//
// Attention : l'émulateur lui-même (entrée en trap, timer qui allume MTIP)
// écrit directement avec set_raw(), SANS passer par ce masque.
// ---------------------------------------------------------------------------
fn write_mask(reg: Config) u32 {
    return switch (reg) {
        .mvendorid, .marchid, .mimpid, .mhartid => 0,
        .misa => 0, // écritures ignorées
        .mstatus => MSTATUS_MIE | MSTATUS_MPIE | MSTATUS_MPP, // 0x1888
        .mstatush => 0, // seulement les bits big-endian, non gérés
        .mie => MIP_MSIP | MIP_MTIP | MIP_MEIP, // 0x888
        .mtvec => 0xfffffffc, // base inscriptible, mode forcé à 0 (direct)
        .mcounteren => 0x7, // CY, TM, IR
        .mscratch => 0xffffffff,
        .mepc => 0xfffffffc, // pas d'extension C : bits 1:0 toujours à 0
        .mcause => 0xffffffff,
        .mtval => 0xffffffff,
        .mip => 0, // tous les bits sont pilotés par le matériel
        .pmpcfg0, .pmpaddr0 => 0, // "j'ai 0 entrée PMP" : se relisent à 0
        .mcycle, .minstret, .mcycleh, .minstreth => 0xffffffff,
        // lecture seule par leur adresse : une écriture est déjà illégale
        .cycle, .time, .instret, .cycleh, .timeh, .instreth => 0,
    };
}

// Lecture d'un CSR. Les compteurs et les constantes ne sont pas dans
// `storage` : on les calcule ici.
pub fn read(reg: Config) u32 {
    return switch (reg) {
        .mvendorid, .marchid, .mimpid, .mhartid => 0,
        .misa => MISA_VALUE,
        .mcycle, .cycle => @truncate(cycle_counter),
        .mcycleh, .cycleh => @truncate(cycle_counter >> 32),
        .minstret, .instret => @truncate(instret_counter),
        .minstreth, .instreth => @truncate(instret_counter >> 32),
        // TODO étape 4 : renvoyer mtime du CLINT
        .time, .timeh => 0,
        else => storage[@intFromEnum(reg)],
    };
}

// Écriture faite par une instruction CSR : on applique le masque.
fn write(reg: Config, value: u32) void {
    switch (reg) {
        // les compteurs : on remplace la moitié correspondante du u64
        .mcycle => {
            cycle_counter = (cycle_counter & 0xffffffff_00000000) | @as(u64, value);
        },
        .mcycleh => {
            cycle_counter = (cycle_counter & 0x00000000_ffffffff) | (@as(u64, value) << 32);
        },
        .minstret => {
            instret_counter = (instret_counter & 0xffffffff_00000000) | @as(u64, value);
        },
        .minstreth => {
            instret_counter = (instret_counter & 0x00000000_ffffffff) | (@as(u64, value) << 32);
        },
        else => {
            const idx = @intFromEnum(reg);
            const mask = write_mask(reg);
            const old = storage[idx];
            var new = (old & ~mask) | (value & mask);

            // MPP n'accepte que 00 (U) et 11 (M). Si on écrit 01 ou 10,
            // on garde l'ancienne valeur de MPP.
            if (reg == .mstatus) {
                const mpp = (new & MSTATUS_MPP) >> 11;
                if (mpp == 0b01 or mpp == 0b10) {
                    new = (new & ~MSTATUS_MPP) | (old & MSTATUS_MPP);
                }
            }
            storage[idx] = new;
        },
    }
}

// Écriture "matérielle" faite par l'émulateur (entrée en trap, timer...).
// Pas de masque, pas de vérification de droits.
pub fn set_raw(reg: Config, value: u32) void {
    storage[@intFromEnum(reg)] = value;
}

fn illegal(reason: []const u8, csr_number: u12) Err {
    std.debug.print("instruction illégale (CSR 0x{x:0>3}) : {s}\n", .{ csr_number, reason });
    return Err.IllegalInstruction;
}

// Est-ce qu'un compteur est lisible depuis le privilège courant ?
// En mode U, il faut que le bit correspondant de mcounteren soit à 1.
fn counter_allowed(reg: Config) bool {
    if (privilege == MACHINE) {
        return true;
    }
    const mcounteren = storage[@intFromEnum(Config.mcounteren)];
    return switch (reg) {
        .cycle, .cycleh => (mcounteren & 1) != 0,
        .time, .timeh => (mcounteren & 2) != 0,
        .instret, .instreth => (mcounteren & 4) != 0,
        else => true,
    };
}

// ---------------------------------------------------------------------------
// Exécution d'une instruction CSR.
// Règle d'or : on lit toutes les sources, on fait TOUTES les vérifications,
// et seulement ensuite on modifie quelque chose (le CSR puis rd).
// Une instruction illégale ne doit avoir aucun effet visible.
// ---------------------------------------------------------------------------
pub fn execute(instr: op.I, kind: CsrOp) Err!void {
    // 1. Le numéro du CSR est TOUJOURS dans les bits 31:20 (champ imm brut,
    //    sans extension de signe), pour les 6 instructions.
    const csr_number: u12 = instr.imm;

    // 2. La source : registre rs1, ou pour les variantes "i" le champ rs1
    //    lui-même, vu comme un immédiat de 5 bits étendu par des zéros.
    //    On la lit MAINTENANT, avant toute écriture (rd peut être == rs1).
    const is_immediate = (kind == .rwi or kind == .rsi or kind == .rci);
    var source: u32 = 0;
    if (is_immediate) {
        source = @as(u32, instr.rs1);
    } else {
        source = bus.regs[instr.rs1];
    }

    // 3. Est-ce qu'on écrit ? Est-ce qu'on lit ?
    //    - csrrw/csrrwi écrivent toujours, mais ne lisent pas si rd == x0
    //    - csrrs/csrrc (et i) lisent toujours, mais n'écrivent pas si le
    //      CHAMP rs1 vaut 0 (index x0, ou immédiat 0) — pas la valeur !
    var will_write = true;
    var will_read = true;
    if (kind == .rw or kind == .rwi) {
        will_read = (instr.rd != 0);
    } else {
        will_write = (instr.rs1 != 0);
    }

    // 4. Les vérifications. Aucune modification avant d'avoir tout vérifié.
    const reg = std.enums.fromInt(Config, csr_number) orelse {
        return illegal("CSR inexistant", csr_number);
    };
    const required_privilege: u2 = @truncate(csr_number >> 8);
    if (required_privilege > privilege) {
        return illegal("privilège insuffisant", csr_number);
    }
    const read_only = (csr_number >> 10) == 0b11;
    if (will_write and read_only) {
        return illegal("écriture dans un CSR en lecture seule", csr_number);
    }
    if (!counter_allowed(reg)) {
        return illegal("compteur interdit en mode U (mcounteren)", csr_number);
    }

    // 5. Lecture de l'ancienne valeur.
    var old: u32 = 0;
    if (will_read) {
        old = read(reg);
    }

    // 6. Calcul et écriture de la nouvelle valeur.
    if (will_write) {
        var new: u32 = 0;
        switch (kind) {
            .rw, .rwi => new = source,
            .rs, .rsi => new = old | source,
            .rc, .rci => new = old & ~source,
        }
        write(reg, new);
    }

    // 7. rd reçoit l'ANCIENNE valeur du CSR.
    if (instr.rd != 0) {
        bus.regs[instr.rd] = old;
    }
}

// ---------------------------------------------------------------------------
// Tests unitaires : `zig test src/csr.zig` ne marche pas seul (imports),
// lance plutôt `zig build test`.
// ---------------------------------------------------------------------------
fn make_instr(csr_number: u12, rs1: u5, rd: u5, funct3: u3) op.I {
    return op.I{ .opcode = 0x73, .rd = rd, .func3 = funct3, .rs1 = rs1, .imm = csr_number };
}

test "csrrw échange un registre avec mscratch (rd == rs1)" {
    privilege = MACHINE;
    set_raw(.mscratch, 0x1111);
    bus.regs[4] = 0x2222; // tp
    try execute(make_instr(0x340, 4, 4, 1), .rw); // csrrw tp, mscratch, tp
    try std.testing.expectEqual(@as(u32, 0x1111), bus.regs[4]);
    try std.testing.expectEqual(@as(u32, 0x2222), read(.mscratch));
}

test "csrr sur un CSR en lecture seule est légal, csrw ne l'est pas" {
    privilege = MACHINE;
    cycle_counter = 42;
    try execute(make_instr(0xc00, 0, 5, 2), .rs); // csrr t0, cycle
    try std.testing.expectEqual(@as(u32, 42), bus.regs[5]);
    bus.regs[6] = 0;
    // csrrs t0, cycle, t1 : t1 vaut 0 mais le CHAMP rs1 != 0 -> tentative d'écriture
    try std.testing.expectError(Err.IllegalInstruction, execute(make_instr(0xc00, 6, 5, 2), .rs));
}

test "masques : misa ignoré, mstatus filtré, MPP illégal refusé" {
    privilege = MACHINE;
    bus.regs[5] = 0xffffffff;
    try execute(make_instr(0x301, 5, 0, 1), .rw); // csrw misa, t0
    try std.testing.expectEqual(MISA_VALUE, read(.misa));
    set_raw(.mstatus, 0);
    try execute(make_instr(0x300, 5, 0, 1), .rw); // csrw mstatus, 0xffffffff
    try std.testing.expectEqual(@as(u32, 0x1888), read(.mstatus));
    bus.regs[5] = 0b01 << 11; // MPP = S, illégal ici
    try execute(make_instr(0x300, 5, 0, 1), .rw);
    try std.testing.expectEqual(@as(u32, 0x1800), read(.mstatus) & MSTATUS_MPP);
}

test "une instruction illégale ne modifie pas rd" {
    privilege = USER;
    bus.regs[5] = 0x1234;
    try std.testing.expectError(Err.IllegalInstruction, execute(make_instr(0x300, 0, 5, 2), .rs)); // csrr t0, mstatus en U
    try std.testing.expectEqual(@as(u32, 0x1234), bus.regs[5]);
    privilege = MACHINE;
}

test "csrrsi / csrrci avec immédiat" {
    privilege = MACHINE;
    set_raw(.mie, 0);
    try execute(make_instr(0x304, 8, 0, 6), .rsi); // csrsi mie, 8 (MSIE)
    try std.testing.expectEqual(@as(u32, 8), read(.mie));
    try execute(make_instr(0x304, 8, 7, 7), .rci); // csrrci t2, mie, 8
    try std.testing.expectEqual(@as(u32, 8), bus.regs[7]);
    try std.testing.expectEqual(@as(u32, 0), read(.mie));
}
