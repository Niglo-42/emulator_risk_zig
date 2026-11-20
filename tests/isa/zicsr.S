# Test maison de Zicsr, au format riscv-tests.
# Chaque TEST_CASE( n, registre, valeur_attendue, code ) exécute `code`
# puis vérifie `registre`. En cas d'échec, l'émulateur sort avec le code n.
# (Les accès illégaux ne sont pas testés ici : sans traps, l'émulateur
# s'arrête. Ils sont couverts par les tests unitaires de src/csr.zig.)

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  # écrire puis relire mscratch
  TEST_CASE( 2, a0, 0x12345678, li t0, 0x12345678; csrw mscratch, t0; csrr a0, mscratch );
  # csrrw rend l'ANCIENNE valeur, même si rd == rs1 (l'échange de l'entrée de trap Linux)
  TEST_CASE( 3, a0, 0x12345678, li a0, 0xabc; csrrw a0, mscratch, a0 );
  TEST_CASE( 4, a0, 0xabc, csrr a0, mscratch );
  # csrs / csrc
  TEST_CASE( 5, a0, 0x88, csrw mie, zero; li t0, 0x88; csrs mie, t0; csrr a0, mie );
  TEST_CASE( 6, a0, 0x80, li t0, 0x8; csrc mie, t0; csrr a0, mie );
  # masque de mie : seuls les bits 3, 7 et 11 existent
  TEST_CASE( 7, a0, 0x888, li t0, -1; csrw mie, t0; csrr a0, mie );
  # misa : écriture ignorée (RV32 + I + M + U)
  TEST_CASE( 8, a0, 0x40101100, csrw misa, zero; csrr a0, misa );
  # masque de mstatus : MIE, MPIE, MPP
  TEST_CASE( 9, a0, 0x1888, li t0, -1; csrw mstatus, t0; csrr a0, mstatus );
  # variantes immédiates
  TEST_CASE( 10, a0, 0x1880, csrci mstatus, 8; csrr a0, mstatus );
  # uimm = 0 : lecture sans écriture
  TEST_CASE( 11, a0, 0x1880, csrrsi a0, mstatus, 0 );
  # identification
  TEST_CASE( 12, a0, 0, csrr a0, mhartid );
  # le compteur de cycles avance
  TEST_CASE( 13, a0, 1, csrr t0, cycle; nop; csrr t1, cycle; sltu a0, t0, t1 );
  # mepc : bits 1:0 forcés à 0 (pas d'extension C)
  TEST_CASE( 14, a0, 0x80000000, li t0, 0x80000003; csrw mepc, t0; csrr a0, mepc );
  # mcycle est inscriptible, et continue à compter après
  TEST_CASE( 15, a0, 1, li t0, 1000; csrw mcycle, t0; csrr a1, mcycle; sub a1, a1, t0; sltiu a0, a1, 10 );
  # mtvec : mode forcé à 0 (direct)
  TEST_CASE( 16, a0, 0x80000100, li t0, 0x80000101; csrw mtvec, t0; csrr a0, mtvec );
  # pmp : accepté, se relit à 0 (0 entrée implémentée)
  TEST_CASE( 17, a0, 0, li t0, -1; csrw pmpaddr0, t0; csrr a0, pmpaddr0 );

  TEST_PASSFAIL

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA

RVTEST_DATA_END
