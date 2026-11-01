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

    buf_test_b = (
        # 0x00: addi x1, x0, 1024      (adresse 0x400)
        b"\x93\x00\x00\x40"
        # 0x04: addi x2, x0, 10        (compteur)
        b"\x13\x01\xa0\x00"
        # 0x08: lw x3, 0(x1)           (début de boucle)
        b"\x83\xa1\x00\x00"
        # 0x0c: addi x3, x3, 1
        b"\x93\x81\x11\x00"
        # 0x10: sw x3, 0(x1)
        b"\x23\xa0\x30\x00"
        # 0x14: addi x2, x2, -1
        b"\x13\x01\xf1\xff"
        # 0x18: bne x2, x0, -16        (retour en 0x08 tant que x2 != 0)
        b"\xe3\x18\x01\xfe"
        # 0x1c: lw x4, 0(x1)           (relecture finale)
        b"\x03\xa2\x00\x00"
    )

    test_ju = (
        # 0x00: jal x0, +12            (saute la fonction ; rien ne doit être écrit dans x0)
b"\x6f\x00\xc0\x00"
# 0x04: addi x13, x0, 1        (corps de la fonction)
b"\x93\x06\x10\x00"
# 0x08: jalr x0, 0(x12)        (retour)
b"\x67\x00\x06\x00"
# 0x0c: lui x1, 0x12345
b"\xb7\x50\x34\x12"
# 0x10: lui x2, 0xfffff
b"\x37\xf1\xff\xff"
# 0x14: auipc x3, 0x1
b"\x97\x11\x00\x00"
# 0x18: auipc x4, 0xfffff
b"\x17\xf2\xff\xff"
# 0x1c: jal x5, +12            (saut en avant vers 0x28)
b"\xef\x02\xc0\x00"
# 0x20: addi x10, x0, 1        (jamais exécuté)
b"\x13\x05\x10\x00"
# 0x24: addi x10, x0, 1        (jamais exécuté)
b"\x13\x05\x10\x00"
# 0x28: addi x6, x0, 1
b"\x13\x03\x10\x00"
# 0x2c: auipc x7, 0
b"\x97\x03\x00\x00"
# 0x30: jalr x8, 13(x7)        (cible impaire : 0x39, le bit 0 doit être effacé, arrivée en 0x38)
b"\x67\x84\xd3\x00"
# 0x34: addi x11, x0, 1        (jamais exécuté)
b"\x93\x05\x10\x00"
# 0x38: addi x9, x0, 1
b"\x93\x04\x10\x00"
# 0x3c: jal x12, -56           (appel de la fonction en 0x04, saut en arrière)
b"\x6f\xf6\x9f\xfc"
# 0x40: addi x14, x0, 1        (atteint après le retour)
b"\x13\x07\x10\x00"
# 0x44: addi x15, x0, 1        (marqueur de fin)
b"\x93\x07\x10\x00"
    )

    file.write(test_ju)