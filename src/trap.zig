// Traps : quand le programme invité provoque un problème (exception) ou
// qu'un événement extérieur arrive (interruption, bloc 3), le CPU ne
// s'arrête pas : il note où il était, pourquoi, avec quel détail, puis
// saute au handler de l'OS dont l'adresse est dans mtvec.
//
// C'est TOUJOURS l'émulateur qui remplit les CSR (comme le matériel),
// et c'est le code INVITÉ (le handler) qui les lit et décide quoi faire.

const std = @import("std");
const csr = @import("csr.zig");
const fetch = @import("fetch_and_decode.zig");

// ---------------------------------------------------------------------------
// Les causes (valeur de mcause). Bit 31 à 0 = exception.
// ---------------------------------------------------------------------------
pub const CAUSE_INSTRUCTION_MISALIGNED: u32 = 0; // saut vers une adresse non multiple de 4
pub const CAUSE_INSTRUCTION_ACCESS_FAULT: u32 = 1; // fetch à une adresse hors du bus
pub const CAUSE_ILLEGAL_INSTRUCTION: u32 = 2;
pub const CAUSE_BREAKPOINT: u32 = 3; // ebreak
pub const CAUSE_LOAD_ACCESS_FAULT: u32 = 5;
pub const CAUSE_STORE_ACCESS_FAULT: u32 = 7;
pub const CAUSE_ECALL_FROM_U: u32 = 8;
pub const CAUSE_ECALL_FROM_M: u32 = 11;

// Bit 31 à 1 = interruption (bloc 3). Ex : timer = INTERRUPT_BIT | 7
pub const INTERRUPT_BIT: u32 = 1 << 31;

// ---------------------------------------------------------------------------
// Les fautes que le code de l'émulateur peut remonter avec `return`.
// Une erreur Zig ne transporte pas de donnée : le détail (qui ira dans
// mtval) est rangé dans `pending_tval` juste avant le `return`.
// ---------------------------------------------------------------------------
pub const Fault = error{
    IllegalInstruction,
    InstructionMisaligned,
    InstructionAccessFault,
    LoadAccessFault,
    StoreAccessFault,
    Ecall,
    Breakpoint,
};

pub var pending_tval: u32 = 0;

// ===========================================================================
// À ÉCRIRE PAR THOMAS (voir le pseudo-code dans la conversation)
// ===========================================================================

/// Entrée en trap. Appelée par la boucle fetch quand une instruction a
/// provoqué une exception (plus tard : quand une interruption est prise).
///   cause : valeur à mettre dans mcause (bit 31 à 1 pour une interruption)
///   tval  : valeur à mettre dans mtval (adresse fautive, instruction, ou 0)
///
/// Au moment de l'appel, fetch.pc vaut encore l'adresse de l'instruction
/// fautive : elle n'a eu aucun effet.
///
/// Outils disponibles :
///   csr.read(.mstatus), csr.set_raw(.mepc, valeur), ...
///   csr.privilege (var u2), csr.MACHINE, csr.USER
///   csr.MSTATUS_MIE, csr.MSTATUS_MPIE, csr.MSTATUS_MPP (masques de bits)
///   fetch.pc (var u32)
pub fn take_trap(cause: u32, tval: u32) void {
    _ = cause;
    _ = tval;
    @panic("trap.take_trap n'est pas encore écrit");
}

/// Instruction mret (0x30200073) : retour du handler.
/// Doit renvoyer Fault.IllegalInstruction si on n'est pas en mode M.
/// Attention : après mret, la boucle ne doit PAS ajouter 4 au pc
/// (c'est géré dans decode : mret compte comme un saut).
pub fn mret() Fault!void {
    @panic("trap.mret n'est pas encore écrit");
}
