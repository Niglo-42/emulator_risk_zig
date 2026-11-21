# Test maison : la réservation de LR/SC face aux traps et aux sc.
# Marche avec les deux environnements (nu et p) : le test installe son
# propre handler le temps du cas 3, puis remet l'ancien mtvec.
# RVTEST_RV32M : en mode U, on n'aurait pas le droit de toucher mtvec.

#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  # 2 : lr puis sc sur la même adresse, sans rien entre les deux -> succès
  TEST_CASE( 2, a4, 0, la a0, foo; lr.w a1, (a0); li a5, 42; sc.w a4, a5, (a0) );

  # 3 : un trap entre lr et sc doit casser la réservation -> sc échoue
  la t0, handler
  csrrw s1, mtvec, t0          # s1 = ancien mtvec
  # (on remet l'ancien mtvec juste après le trap : si le test échoue, le
  # FAIL de l'environnement p passe par un ecall et a besoin de son handler)
  TEST_CASE( 3, a4, 1, la a0, foo; lr.w a1, (a0); .word 0; csrw mtvec, s1; li a5, 7; sc.w a4, a5, (a0) );
  # 4 : et le sc raté n'a rien écrit (foo vaut toujours 42)
  TEST_CASE( 4, a4, 42, lw a4, foo );

  # 5 : un sc consomme la réservation : un second sc échoue
  TEST_CASE( 5, a4, 1, la a0, foo; lr.w a1, (a0); sc.w a6, a1, (a0); sc.w a4, a1, (a0) );

  # 6 : la réservation est pour UNE adresse : sc ailleurs échoue
  TEST_CASE( 6, a4, 1, la a0, foo; la a2, bar; lr.w a1, (a0); sc.w a4, a1, (a2) );

  # 7 : un nouveau lr remplace l'ancienne réservation
  TEST_CASE( 7, a4, 0, la a0, foo; la a2, bar; lr.w a1, (a0); lr.w a1, (a2); sc.w a4, a1, (a2) );

  TEST_PASSFAIL

  # handler minimal : saute l'instruction illégale (.word 0) et revient
  .align 2
handler:
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  TEST_DATA
  .align 2
foo: .word 0
bar: .word 0

RVTEST_DATA_END
