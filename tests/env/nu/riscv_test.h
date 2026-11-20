// Environnement minimal pour lancer les riscv-tests dans notre émulateur.
//
// Différence avec l'environnement officiel (env/p) : pas de trap, pas de
// tohost. Le test signale son résultat en écrivant dans le "finisher"
// (0x100000, voir src/finisher.zig) :
//   PASS -> 0x5555
//   FAIL -> 0x3333 | (numéro du test raté << 16)
//
// Utilisé tant que les traps ne marchent pas. Ensuite, préfère ENV=p (voir
// tests/env/p), qui fait tourner les tests rv32ui en mode U.

#ifndef _ENV_EMU_H
#define _ENV_EMU_H

// Les tests choisissent leur "type" avec ces macros. On ne fait rien de
// spécial : tout tourne en mode machine.
#define RVTEST_RV32U .macro init; .endm
#define RVTEST_RV64U .macro init; .endm
#define RVTEST_RV32UF .macro init; .endm
#define RVTEST_RV64UF .macro init; .endm
#define RVTEST_RV32M .macro init; .endm
#define RVTEST_RV64M .macro init; .endm

// numéro du test en cours (gp = x3), mis à jour par chaque TEST_CASE
#define TESTNUM gp

#define FINISHER_ADDR 0x100000

#define RVTEST_CODE_BEGIN                                               \
        .section .text.init;                                            \
        .align  6;                                                      \
        .globl _start;                                                  \
_start:                                                                 \
        /* tous les registres à 0 pour partir d'un état connu */       \
        li x1, 0;  li x2, 0;  li x3, 0;  li x4, 0;                      \
        li x5, 0;  li x6, 0;  li x7, 0;  li x8, 0;                      \
        li x9, 0;  li x10, 0; li x11, 0; li x12, 0;                     \
        li x13, 0; li x14, 0; li x15, 0; li x16, 0;                     \
        li x17, 0; li x18, 0; li x19, 0; li x20, 0;                     \
        li x21, 0; li x22, 0; li x23, 0; li x24, 0;                     \
        li x25, 0; li x26, 0; li x27, 0; li x28, 0;                     \
        li x29, 0; li x30, 0; li x31, 0;                                \
        init;

#define RVTEST_CODE_END                                                 \
        unimp

// PASS : on écrit 0x5555 dans le finisher, puis on boucle au cas où
#define RVTEST_PASS                                                     \
        fence;                                                          \
        li t0, FINISHER_ADDR;                                           \
        li t1, 0x5555;                                                  \
        sw t1, 0(t0);                                                   \
1:      j 1b;

// FAIL : 0x3333 | (TESTNUM << 16). TESTNUM ne doit jamais valoir 0 ici.
#define RVTEST_FAIL                                                     \
        fence;                                                          \
1:      beqz TESTNUM, 1b;                                               \
        li t0, FINISHER_ADDR;                                           \
        slli t1, TESTNUM, 16;                                           \
        li t2, 0x3333;                                                  \
        or t1, t1, t2;                                                  \
        sw t1, 0(t0);                                                   \
1:      j 1b;

#define EXTRA_DATA

#define RVTEST_DATA_BEGIN                                               \
        EXTRA_DATA                                                      \
        .align 4; .global begin_signature; begin_signature:

#define RVTEST_DATA_END .align 4; .global end_signature; end_signature:

#endif
