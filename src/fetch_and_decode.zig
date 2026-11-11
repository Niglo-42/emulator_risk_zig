const sys = @import("syscall.zig");
const bus = @import("bus.zig");
const dbg = @import("dbg.zig");
const op = @import("op.zig");
const INSTRUCTION = op.INSTRUCTION;
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
            switch (instruction.R.func3) {
                0 => {
                    if (instruction.R.func7 == 0x20) {
                        op._R(instruction.R, op.sub);
                    } else {
                        op._R(instruction.R, op.add);
                    }
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
                    if (instruction.R.func7 == 0x20) {
                        op._R(instruction.R, op.sra);
                    } else {
                        op._R(instruction.R, op.srl);
                    }
                },
                6 => {
                    op._R(instruction.R, op.or_);
                },
                7 => {
                    op._R(instruction.R, op.and_);
                },
            }
        },
        0x13 => {
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
                    if (instruction.R.func7 == 0x20) {
                        op._I(instruction.I, op.sra);
                    } else {
                        op._I(instruction.I, op.srl);
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

pub fn fetch(instr_size: u8, debug: bool) !void {
    while (true) {
        try decode(try bus.fetch_mem(pc, instr_size), debug);
    }
    if (debug) {
        dbg.print_regs();
    }
}
