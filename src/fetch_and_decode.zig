const bus = @import("bus.zig");
const dbg = @import("dbg.zig");
const op = @import("op.zig");
const stdin = @import("stdin.zig");
const main = @import("main.zig");
const std = @import("std");
const time = std.time;
const INSTRUCTION = op.INSTRUCTION;
const csr = @import("csr.zig");
const trap = @import("trap.zig");
pub var pc: u32 = 0;

const Err = error{
    Decode,
    UnknownInstruction,
    InvalidFunc3,
};

fn decode(instr: u32, debug: bool) !void {
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
                            return trap.Fault.IllegalInstruction;
                        },
                    }
                },
                else => {
                    // avant : ignoré en silence -> une instruction inconnue
                    // devenait un "nop" invisible
                    return trap.Fault.IllegalInstruction;
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
                        return trap.Fault.IllegalInstruction;
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
                        return trap.Fault.IllegalInstruction;
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
            //B : funct3 2 et 3 n'existent pas (op._B renvoie une faute)
            flag = try op._B(instruction.B);
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
            try op.jal(instruction.J);
            flag = true;
        },
        0x67 => {
            if (instruction.I.func3 != 0) {
                return trap.Fault.IllegalInstruction;
            }
            try op.jalr(instruction.I);
            flag = true;
        },
        0x73 => {
            // system
            //ecall = 0x73 pure
            switch (instruction.I.func3) 
            {
                0 => 
                {
                    // funct3 = 0 : instructions privilégiées, reconnues à
                    // leur champ imm (bits 31:20), avec rs1 = rd = 0.
                    // ecall n'appelle plus l'hôte : c'est une exception,
                    // gérée par le handler du guest (son kernel).
                    if (instruction.I.rs1 != 0 or instruction.I.rd != 0) {
                        return trap.Fault.IllegalInstruction;
                    }
                    switch (instruction.I.imm) {
                        0x000 => return trap.Fault.Ecall,
                        0x001 => return trap.Fault.Breakpoint,
                        0x302 => {
                            // mret écrit lui-même le pc : comme un saut
                            try trap.mret();
                            flag = true;
                        },
                        0x105 => {
                            // wfi : "attends une interruption". Pour l'instant
                            // un nop en mode M (bloc 3 : vraie attente).
                            if (csr.privilege != csr.MACHINE) {
                                return trap.Fault.IllegalInstruction;
                            }
                        },
                        else => return trap.Fault.IllegalInstruction,
                    }
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
                    return trap.Fault.IllegalInstruction;
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
        0x2f => {
            // extension A : lr.w, sc.w et les 9 AMO
            try op._amo(instruction.R);
        },
        0xf => {
            // fence (funct3 0) et fence.i (funct3 1) : rien à faire chez
            // nous (un seul cœur, pas de cache). Le reste est illégal.
            if (instruction.I.func3 > 1) {
                return trap.Fault.IllegalInstruction;
            }
            //FENCE (opcode 0x0F, funct3 = 0)
            //Ses champs sont fm (bits 31:28),
            //pred (27:24) et succ (23:20).
            // Chaque ensemble pred/succ compose quatre bits :
            // I (entrée), O (sortie), R (lecture) et W (écriture),
            //avec I = bit 3 et W = bit 0
        },
        else => {
            return trap.Fault.IllegalInstruction;
        },
    }
    if (flag == false) {
        pc += 4;
    }
    bus.regs[0] = 0; // force x0 à 0
}

// Instruction



// Transforme une erreur remontée par decode en trap pour le guest.
// Toute erreur qui n'est PAS une faute du guest est un bug de l'émulateur :
// on la laisse remonter et l'émulateur s'arrête.
fn handle_fault(err: anyerror, instr: u32, debug: bool) !void {
    switch (err) {
        error.IllegalInstruction => {
            // mtval = les 32 bits de l'instruction illégale
            try raise(trap.CAUSE_ILLEGAL_INSTRUCTION, instr, debug);
        },
        error.InstructionMisaligned => {
            try raise(trap.CAUSE_INSTRUCTION_MISALIGNED, trap.pending_tval, debug);
        },
        error.LoadMisaligned => {
            try raise(trap.CAUSE_LOAD_MISALIGNED, trap.pending_tval, debug);
        },
        error.StoreMisaligned => {
            try raise(trap.CAUSE_STORE_MISALIGNED, trap.pending_tval, debug);
        },
        error.LoadAccessFault => {
            try raise(trap.CAUSE_LOAD_ACCESS_FAULT, trap.pending_tval, debug);
        },
        error.StoreAccessFault => {
            try raise(trap.CAUSE_STORE_ACCESS_FAULT, trap.pending_tval, debug);
        },
        error.Ecall => {
            // la cause dépend de QUI fait l'appel
            if (csr.privilege == csr.USER) {
                try raise(trap.CAUSE_ECALL_FROM_U, 0, debug);
            } else {
                try raise(trap.CAUSE_ECALL_FROM_M, 0, debug);
            }
        },
        error.Breakpoint => {
            // mtval = l'adresse de l'ebreak
            try raise(trap.CAUSE_BREAKPOINT, pc, debug);
        },
        else => {
            std.debug.print("bug de l'émulateur : {s} à pc=0x{x:0>8}, instruction=0x{x:0>8}\n", .{ @errorName(err), pc, instr });
            if (debug) {
                dbg.print_regs();
            }
            return err;
        },
    }
}

// Filet de sécurité : si le guest n'a jamais installé de handler
// (mtvec == 0, et l'adresse 0 n'est pas de la RAM chez nous), sauter à 0
// ferait boucler l'émulateur sur des fautes à l'infini. On s'arrête en
// expliquant pourquoi. C'est le cas des petits programmes C sans handler.
fn raise(cause: u32, tval: u32, debug: bool) !void {
    if (debug) {
        std.debug.print("trap : mcause={d}, pc=0x{x:0>8}, mtval=0x{x:0>8}\n", .{ cause, pc, tval });
        if (cause == trap.CAUSE_ILLEGAL_INSTRUCTION and csr.last_illegal_reason.len > 0) {
            std.debug.print("       CSR 0x{x:0>3} : {s}\n", .{ csr.last_illegal_csr, csr.last_illegal_reason });
        }
    }
    csr.last_illegal_reason = "";
    if (csr.read(.mtvec) == 0) {
        std.debug.print("trap sans handler (mtvec = 0) : mcause={d}, pc=0x{x:0>8}, mtval=0x{x:0>8}\n", .{ cause, pc, tval });
        if (debug) {
            dbg.print_regs();
        }
        return error.NoTrapHandler;
    }
    trap.take_trap(cause, tval);
}

// mis à true si le CPU s'arrête sur une erreur (bug de l'émulateur, ou
// trap sans handler) : main sort alors avec le code 2
pub var crashed = false;

pub fn fetch(instr_size: u8, debug: bool, input_mode: bool) !void {
    // Quoi qu'il arrive (fin normale OU erreur), on prévient la fenêtre et
    // main que le CPU s'est arrêté. Sans ce defer, une erreur dans ce thread
    // le termine en silence et la fenêtre reste ouverte.
    defer main.flag.store(true, .monotonic);
    errdefer crashed = true;
    var compteur: u16 = 0;

    while (true) {
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
        // 1 instruction = 1 cycle, qu'elle aboutisse ou qu'elle trappe
        csr.cycle_counter +%= 1;
        compteur = compteur +% 1;

        // fetch : une adresse hors du bus est une faute d'accès instruction
        const instr = bus.fetch_mem(pc, instr_size) catch {
            try raise(trap.CAUSE_INSTRUCTION_ACCESS_FAULT, pc, debug);
            continue;
        };
        decode(instr, debug) catch |err| {
            try handle_fault(err, instr, debug);
            // instruction non retirée : pas d'incrément de instret
            continue;
        };
        // une instruction de plus retirée (sauf si elle vient d'écrire
        // minstret elle-même : voir csr.instret_written)
        if (csr.instret_written) {
            csr.instret_written = false;
        } else {
            csr.instret_counter +%= 1;
        }
    }
    if (debug) {
        dbg.print_regs();
    }
}
