.section .text
.globl _start

_start:
    li sp, 0x80000
    call main

    # code 93 = exit
    li a7, 93
    ecall

1:
    # infinite loop si exit fail
    j 1b
