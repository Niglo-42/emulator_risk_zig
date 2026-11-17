const sys = @import("syscall.zig");
const bus = @import("bus.zig");
const dbg = @import("dbg.zig");
const op = @import("op.zig");
const stdin = @import("stdin.zig");
const main = @import("main.zig");
const std = @import("std");
const time = std.time;
const INSTRUCTION = op.INSTRUCTION;
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
                        else => {},
                    }
                },
                else => {},
            }
        },
        0x13 => {
            switch (instruction.R.func7) {
                0x20 => {
                    if (instruction.R.func3 == 5) {
                        op._I(instruction.I, op.sra);
                    }
                },
                0 => {
                    switch (instruction.I.func3) {
                        0 => {
                            op._I(instruction.I, op.add);
                        },
                        1 => {
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
                            op._I(instruction.I, op.srl);
                        },
                        6 => {
                            op._I(instruction.I, op.or_);
                        },
                        7 => {
                            op._I(instruction.I, op.and_);
                        },
                    }
                },
                else => {},
            }
        },
        3 => {
            try op._load(instruction.I);
        },
        0x63 => {
            //B
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
            if (instruction.I.func3 == 0) {
                if (instruction.I.get_imm() == 0) {
                    if (bus.regs[17] == 93) {
                        run.* = false;
                        return;
                    }
                    try sys.syscall();
                } else if (instruction.I.imm == 1) {
                    //ebreak 0x00100073
                }
            } else {
                return Err.Decode;
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
    var compteur: u16 = 0;
    var run = true;
    while (run) {
        if (compteur == 0) {
            if (input_mode == false) {
                try stdin.serve_the_world();
            }
            if (main.flag.load(.monotonic) == true) {
                break;
            }
        }
        try decode(try bus.fetch_mem(pc, instr_size), debug, &run);
        compteur = compteur +% 1;
    }
    if (debug) {
        dbg.print_regs();
    }
    main.flag.store(true, .monotonic);
}
