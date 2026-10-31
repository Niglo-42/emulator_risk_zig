with open("bin.bin", "wb") as file:
    buf_ri = (
        # addi x1, x0, 10
        b"\x93\x00\xa0\x00"
        # addi x2, x0, 20
        b"\x13\x01\x40\x01"
        # add x3, x1, x2
        b"\xb3\x81\x20\x00"
        # sub x4, x2, x1
        b"\x33\x02\x11\x40"
        # and x5, x1, x2
        b"\xb3\xf2\x20\x00"
        # or x6, x1, x2
        b"\x33\xe3\x20\x00"
        # xor x7, x1, x2
        b"\xb3\xc3\x20\x00"
        # sll x8, x1, x2
        b"\x33\x94\x20\x00"
        # srl x9, x2, x1
        b"\xb3\x54\x11\x00"
        # sra x10, x2, x1
        b"\x33\x55\x11\x40"
        # slt x11, x1, x2
        b"\xb3\xa5\x20\x00"
        # sltu x12, x1, x2
        b"\x33\xb6\x20\x00"
        # addi x13, x1, -5
        b"\x93\x86\xb0\xff"
        # andi x14, x2, 15
        b"\x13\x77\xf1\x00"
        # ori x15, x1, 8
        b"\x93\xe7\x80\x00"
        # xori x16, x2, 7
        b"\x13\x48\x71\x00"
        # slli x17, x1, 2
        b"\x93\x98\x20\x00"
        # srli x18, x2, 1
        b"\x13\x59\x11\x00"
        # slti x19, x1, 15
        b"\x93\xa9\xf0\x00"
        # sltiu x20, x1, 15
        b"\x13\xba\xf0\x00"
    )
    buf =  (
        # addi x1, x0, 1024
        b"\x93\x00\x00\x40"
        # addi x2, x0, 127
        b"\x13\x01\xf0\x07"
        # slli x2, x2, 8
        b"\x13\x11\x81\x00"
        # addi x2, x2, 128
        b"\x13\x01\x01\x08"
        # addi x3, x0, 1
        b"\x93\x01\x10\x00"
        # slli x3, x3, 15
        b"\x93\x91\xf1\x00"
        # addi x3, x3, 1
        b"\x93\x81\x11\x00"
        # slli x3, x3, 16
        b"\x93\x91\x01\x01"
        # or x2, x2, x3        (x2 = 0x80017F80)
        b"\x33\x61\x31\x00"
        # addi x5, x0, -1
        b"\x93\x02\xf0\xff"
        # sw x2, 0(x1)
        b"\x23\xa0\x20\x00"
        # sh x2, 8(x1)
        b"\x23\x94\x20\x00"
        # sb x2, 12(x1)
        b"\x23\x86\x20\x00"
        # sw x2, 100(x1)
        b"\x23\xa2\x20\x06"
        # addi x4, x1, 64
        b"\x13\x82\x00\x04"
        # sb x2, -1(x4)
        b"\xa3\x0f\x22\xfe"
        # sh x2, -6(x4)
        b"\x23\x1d\x22\xfe"
        # sw x2, -12(x4)
        b"\x23\x2a\x22\xfe"
        # sw x5, 16(x1)
        b"\x23\xa8\x50\x00"
        # sb x0, 17(x1)
        b"\xa3\x88\x00\x00"
        # sw x5, 20(x1)
        b"\x23\xaa\x50\x00"
        # sh x0, 22(x1)
        b"\x23\x9b\x00\x00"
        # lw x10, 0(x1)
        b"\x03\xa5\x00\x00"
        # lb x11, 0(x1)
        b"\x83\x85\x00\x00"
        # lbu x12, 0(x1)
        b"\x03\xc6\x00\x00"
        # lb x13, 1(x1)
        b"\x83\x86\x10\x00"
        # lb x14, 3(x1)
        b"\x03\x87\x30\x00"
        # lbu x15, 3(x1)
        b"\x83\xc7\x30\x00"
        # lh x16, 0(x1)
        b"\x03\x98\x00\x00"
        # lhu x17, 0(x1)
        b"\x83\xd8\x00\x00"
        # lh x18, 2(x1)
        b"\x03\x99\x20\x00"
        # lhu x19, 2(x1)
        b"\x83\xd9\x20\x00"
        # lw x20, 100(x1)
        b"\x03\xaa\x40\x06"
        # lw x21, 8(x1)
        b"\x83\xaa\x80\x00"
        # lw x22, 12(x1)
        b"\x03\xab\xc0\x00"
        # lb x23, -1(x4)
        b"\x83\x0b\xf2\xff"
        # lh x24, -6(x4)
        b"\x03\x1c\xa2\xff"
        # lw x25, -12(x4)
        b"\x83\x2c\x42\xff"
        # lw x26, 16(x1)
        b"\x03\xad\x00\x01"
        # lw x27, 20(x1)
        b"\x83\xad\x40\x01"
        # lw x0, 0(x1)         (x0 doit rester à 0)
        b"\x03\xa0\x00\x00"
    )
    # mem attendu pour LRSI
    # 0x400: 80 7f 01 80     0x434: 80 7f 01 80
    # 0x408: 80 7f 00 00     0x438: 00 00 80 7f
    # 0x40c: 80 00 00 00     0x43c: 00 00 00 80
    # 0x410: ff 00 ff ff     0x464: 80 7f 01 80
    # 0x414: ff ff 00 00
    
    buf_test_b =  (
        # addi x1, x0, 5
        b"\x93\x00\x50\x00"
        # addi x2, x0, 5
        b"\x13\x01\x50\x00"
        # addi x3, x0, 7
        b"\x93\x01\x70\x00"
        # addi x4, x0, -1
        b"\x13\x02\xf0\xff"
        # --- beq pris (x1 == x2) -> x5
        # addi x5, x0, 1
        b"\x93\x02\x10\x00"
        # beq x1, x2, +8
        b"\x63\x84\x20\x00"
        # addi x5, x0, 0
        b"\x93\x02\x00\x00"
        # --- beq non pris (x1 != x3) -> x6
        # addi x6, x0, 0
        b"\x13\x03\x00\x00"
        # beq x1, x3, +8
        b"\x63\x84\x30\x00"
        # addi x6, x0, 1
        b"\x13\x03\x10\x00"
        # --- bne pris -> x7
        # addi x7, x0, 1
        b"\x93\x03\x10\x00"
        # bne x1, x3, +8
        b"\x63\x94\x30\x00"
        # addi x7, x0, 0
        b"\x93\x03\x00\x00"
        # --- bne non pris -> x8
        # addi x8, x0, 0
        b"\x13\x04\x00\x00"
        # bne x1, x2, +8
        b"\x63\x94\x20\x00"
        # addi x8, x0, 1
        b"\x13\x04\x10\x00"
        # --- blt pris (5 < 7) -> x9
        # addi x9, x0, 1
        b"\x93\x04\x10\x00"
        # blt x1, x3, +8
        b"\x63\xc4\x30\x00"
        # addi x9, x0, 0
        b"\x93\x04\x00\x00"
        # --- blt non pris (7 < 5 faux) -> x10
        # addi x10, x0, 0
        b"\x13\x05\x00\x00"
        # blt x3, x1, +8
        b"\x63\xc4\x11\x00"
        # addi x10, x0, 1
        b"\x13\x05\x10\x00"
        # --- blt pris en signé (-1 < 5) -> x11
        # addi x11, x0, 1
        b"\x93\x05\x10\x00"
        # blt x4, x1, +8
        b"\x63\x44\x12\x00"
        # addi x11, x0, 0
        b"\x93\x05\x00\x00"

        # --- bge pris (7 >= 5) -> x12
        # addi x12, x0, 1
        b"\x13\x06\x10\x00"
        # bge x3, x1, +8
        b"\x63\xd4\x11\x00"
        # addi x12, x0, 0
        b"\x13\x06\x00\x00"
        # --- bge pris sur égalité -> x13
        # addi x13, x0, 1
        b"\x93\x06\x10\x00"
        # bge x1, x2, +8
        b"\x63\xd4\x20\x00"
        # addi x13, x0, 0
        b"\x93\x06\x00\x00"
        # --- bge non pris en signé (-1 >= 5 faux) -> x14
        # addi x14, x0, 0
        b"\x13\x07\x00\x00"
        # bge x4, x1, +8
        b"\x63\x54\x12\x00"
        # addi x14, x0, 1
        b"\x13\x07\x10\x00"
        # --- bltu pris (5 < 7) -> x15
        # addi x15, x0, 1
        b"\x93\x07\x10\x00"
        # bltu x1, x3, +8
        b"\x63\xe4\x30\x00"
        # addi x15, x0, 0
        b"\x93\x07\x00\x00"
        # --- bltu non pris (0xFFFFFFFF < 5 faux) -> x16
        # addi x16, x0, 0
        b"\x13\x08\x00\x00"
        # bltu x4, x1, +8
        b"\x63\x64\x12\x00"
        # addi x16, x0, 1
        b"\x13\x08\x10\x00"
        # --- bltu pris (5 < 0xFFFFFFFF) -> x17
        # addi x17, x0, 1
        b"\x93\x08\x10\x00"
        # bltu x1, x4, +8
        b"\x63\xe4\x40\x00"
        # addi x17, x0, 0
        b"\x93\x08\x00\x00"
        # --- bgeu pris (0xFFFFFFFF >= 5) -> x18
        # addi x18, x0, 1
        b"\x13\x09\x10\x00"


        # bgeu x4, x1, +8
        b"\x63\x74\x12\x00"
        # addi x18, x0, 0
        b"\x13\x09\x00\x00"
        # --- bgeu pris sur égalité -> x19
        # addi x19, x0, 1
        b"\x93\x09\x10\x00"
        # bgeu x1, x2, +8
        b"\x63\xf4\x20\x00"
        # addi x19, x0, 0
        b"\x93\x09\x00\x00"
        # --- bgeu non pris (5 >= 7 faux) -> x20
        # addi x20, x0, 0
        b"\x13\x0a\x00\x00"
        # bgeu x1, x3, +8
        b"\x63\xf4\x30\x00"
        # addi x20, x0, 1
        b"\x13\x0a\x10\x00"
        # --- boucle en arrière (offset négatif) : x22 compte 3 tours, x21 finit à 0
        # addi x21, x0, 3
        b"\x93\x0a\x30\x00"
        # addi x22, x22, 1
        b"\x13\x0b\x1b\x00"
        # addi x21, x21, -1
        b"\x93\x8a\xfa\xff"
        # bne x21, x0, -8
        b"\xe3\x9c\x0a\xfe"
        # --- saut en avant de +84 -> x23
        # addi x23, x0, 1


        b"\x93\x0b\x10\x00"
        # beq x0, x0, +84
        b"\x63\x0a\x00\x04"
        # 20 x addi x23, x0, 0 (jamais exécutés)
        b"\x93\x0b\x00\x00" # normalement * 20
        # --- saut en avant de +2048 (bit imm[11] à 1) -> x24
        # addi x24, x0, 1
        b"\x13\x0c\x10\x00"
        # beq x0, x0, +2048
        b"\xe3\x00\x00\x00"
        # 511 x addi x24, x0, 0 (jamais exécutés)
        b"\x13\x0c\x00\x00" # normalement * 511
        # marqueur de fin atteinte
        # addi x25, x0, 1
        b"\x93\x0c\x10\x00"
    )
    # meme attendu pour B 
    # R0:  0x00000000
    # R1:  0x00000005    R2:  0x00000005
    # R3:  0x00000007    R4:  0xffffffff
    # R5 à R20: 0x00000001  (les 16 tests)
    # R21: 0x00000000    R22: 0x00000003
    # R23: 0x00000001    R24: 0x00000001
    # R25: 0x00000001
    # R26 à R31: 0

    file.write(buf)