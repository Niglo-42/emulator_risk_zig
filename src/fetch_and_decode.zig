const sys = @import("syscall.zig");
const bus = @import("bus.zig");
const dbg = @import("dbg.zig");
const op = @import("op.zig");
const stdin = @import("stdin.zig");
const main = @import("main.zig");
const std = @import("std");
const time = std.time;
const INSTRUCTION = op.INSTRUCTION;
const csr = @import("csr.zig");
pub var pc: u32 = 0;

const Err = error{
    Decode,
    UnknownInstruction,
    InvalidFunc3,
};

fn decode(instr: u32, debug: bool, run: *bool) !void {
    const instruction: INSTRUCTION = @bitCast(instr);
    if (debug) {
        dbg.disassembly(instruction);
    }

    var flag = false;
    switch (instruction.R.opcode) {
        0x33 => {
            switch (instruction.R.func7) {
                0 => {
                    switch (instruction.R.func3) {
                        0 => {
                            op._R(instruction.R, op.add);
                        },
                        1 => {
                            op._R(instruction.R, op.sll);
                        },
                        2 => {
                            op._R(instruction.R, op.slt);
                        },
                        3 => {
                            op._R(instruction.R, op.sltu);
                        },
                        4 => {
                            op._R(instruction.R, op.xor);
                        },
                        5 => {
                            op._R(instruction.R, op.srl);
                        },
                        6 => {
                            op._R(instruction.R, op.or_);
                        },
                        7 => {
                            op._R(instruction.R, op.and_);
                        },
                    }
                },
                1 => {
                    switch (instruction.R.func3) {
                        0 => {
                            op._R(instruction.R, op.mul);
                        },
                        1 => {
                            op._R(instruction.R, op.mulh);
                        },
                        2 => {
                            op._R(instruction.R, op.mulhsu);
                        },
                        3 => {
                            op._R(instruction.R, op.mulhu);
                        },
                        4 => {
                            op._R(instruction.R, op.div);
                        },
                        5 => {
                            op._R(instruction.R, op.divu);
                        },
                        6 => {
                            op._R(instruction.R, op.rem);
                        },
                        7 => {
                            op._R(instruction.R, op.remu);
                        },
                    }
                },
                0x20 => {
                    switch (instruction.R.func3) {
                        0 => {
                            op._R(instruction.R, op.sub);
                        },
                        5 => {
                            op._R(instruction.R, op.sra);
                        },
                        else => {
                            return Err.UnknownInstruction;
                        },
                    }
                },
                else => {
                    // avant : ignoré en silence -> une instruction inconnue
                    // devenait un "nop" invisible
                    return Err.UnknownInstruction;
                },
            }
        },
        0x13 => {
            switch (instruction.I.func3) {
                0 => {
                    op._I(instruction.I, op.add);
                },
                1 => {
                    // slli : les bits 31:25 doivent valoir 0 en RV32
                    if (instruction.R.func7 != 0) {
                        return Err.UnknownInstruction;
                    }
                    op._I(instruction.I, op.sll);
                },
                2 => {
                    op._I(instruction.I, op.slt);
                },
                3 => {
                    op._I(instruction.I, op.sltu);
                },
                4 => {
                    op._I(instruction.I, op.xor);
                },
                5 => {
                    // srli et srai partagent funct3 = 5 : c'est le bit 30
                    // (bits 31:25 = 0x20) qui les distingue. L'assembleur
                    // transforme aussi "sra a0, a0, 1" en srai.
                    // op.sra ne garde que les 5 bits bas de l'immédiat (le
                    // shamt), donc le 0x400 du bit 30 ne le gêne pas.
                    if (instruction.R.func7 == 0x20) {
                        op._I(instruction.I, op.sra);
                    } else if (instruction.R.func7 == 0) {
                        op._I(instruction.I, op.srl);
                    } else {
                        return Err.UnknownInstruction;
                    }
                },
                6 => {
                    op._I(instruction.I, op.or_);
                },
                7 => {
                    op._I(instruction.I, op.and_);
                },
            }
        },
        3 => {
            try op._load(instruction.I);
        },
        0x63 => {
            //B : funct3 2 et 3 n'existent pas
            if (instruction.B.func3 == 2 or instruction.B.func3 == 3) {
                return Err.UnknownInstruction;
            }
            flag = op._B(instruction.B);
        },
        0x23 => {
            try op._S(instruction.S);
        },
        0x37 => {
            op.lui(instruction.U);
        },
        0x17 => {
            op.auipc(instruction.U);
        },
        0x6f => {
            flag = true;
            op.jal(instruction.J);
        },
        0x67 => {
            flag = true;
            op.jalr(instruction.I);
        },
        0x73 => {
            // system
            //ecall = 0x73 pure
            switch (instruction.I.func3) 
            {
                0 => 
                {
                    if (bus.regs[17] == 93) { // pour garantir le defer
                        run.* = false;          // dans main
                        return;
                    }
                    try sys.syscall();
                },
                1 =>
                {
                    try csr.execute(instruction.I, .rw);
                },
                2 =>
                {
                    try csr.execute(instruction.I, .rs);
                },
                3 =>
                {
                    try csr.execute(instruction.I, .rc);
                },
                4 =>
                {
                    // funct3 100 est réservé : instruction illégale
                    return Err.UnknownInstruction;
                },
                5 =>
                {
                    try csr.execute(instruction.I, .rwi);
                },
                6 =>
                {
                    try csr.execute(instruction.I, .rsi);
                },
                7 =>
                {
                    try csr.execute(instruction.I, .rci);
                },
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
            return Err.UnknownInstruction;
        },
    }
    if (flag == false) {
        pc += 4;
    }
    bus.regs[0] = 0; // force x0 à 0
}

// Instruction

// Opération
// MUL
// Multiplication, partie basse
// MULH
// Multiplication signed × signed, partie haute
// MULHU
// Multiplication unsigned × unsigned, partie haute
// MULHSU
// Multiplication signed × unsigned, partie haute
// MULW
// Multiplication sur 32 bits (RV64 uniquement)

pub fn fetch(instr_size: u8, debug: bool, input_mode: bool) !void {
    // Quoi qu'il arrive (fin normale OU erreur), on prévient la fenêtre et
    // main que le CPU s'est arrêté. Sans ce defer, une erreur dans ce thread
    // le termine en silence et la fenêtre reste ouverte.
    defer main.flag.store(true, .monotonic);
    var compteur: u16 = 0;
    var run = true;
    while (run) {
        if (compteur == 0) {
            if (input_mode == false) {
                try stdin.serve_the_world();
            }
        }
        // vérifié à chaque instruction : un load atomique "monotonic"
        // coûte le prix d'un load normal.
        if (main.flag.load(.monotonic) == true) {
            break;
        }
        const instr = try bus.fetch_mem(pc, instr_size);
        decode(instr, debug, &run) catch |err| {
            std.debug.print("arrêt sur erreur {s} à pc=0x{x:0>8}, instruction=0x{x:0>8}\n", .{ @errorName(err), pc, instr });
            if (debug) {
                dbg.print_regs();
            }
            return err;
        };
        // une instruction de plus retirée (et 1 instruction = 1 cycle ici)
        csr.instret_counter +%= 1;
        csr.cycle_counter +%= 1;
        compteur = compteur +% 1;
    }
    if (debug) {
        dbg.print_regs();
    }
}
