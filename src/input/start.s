.section .text
.globl _start

_start:
    la sp, _stack_top
    call main

    # Fin du programme : on arrête la machine avec le finisher (0x100000,
    # voir src/finisher.zig). Avant, c'était un ecall 93 traduit vers
    # l'hôte ; depuis les traps, un ecall saute au handler du guest.
    #   main a rendu 0       -> 0x5555 (succès)
    #   main a rendu n != 0  -> 0x3333 | (n << 16) (échec avec le code n)
    li t0, 0x100000
    beqz a0, 1f
    slli a0, a0, 16
    li t1, 0x3333
    or a0, a0, t1
    sw a0, 0(t0)
    j 2f
1:
    li t1, 0x5555
    sw t1, 0(t0)
2:
    # au cas où l'écriture n'arrêterait pas la machine
    j 2b
