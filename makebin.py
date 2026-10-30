with open("bin.bin", "wb") as file:
    buf = (
        # addi x1, x0, 10
        b"\x13\x00\xa0\x00"
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
        b"\x33\xd5\x11\x40"
        # slt x11, x1, x2
        b"\xb3\xa5\x20\x00"
        # sltu x12, x1, x2
        b"\x33\xb6\x20\x00"
        # addi x13, x1, -5
        b"\x93\x06\xb0\xff"
        # andi x14, x2, 15
        b"\x13\x77\xf1\x00"
        # ori x15, x1, 8
        b"\x93\xe7\x80\x00"
        # xori x16, x2, 7
        b"\x13\xc8\x71\x00"
        # slli x17, x1, 2
        b"\x93\x98\x20\x00"
        # srli x18, x2, 1
        b"\x13\xd9\x10\x00"
        # slti x19, x1, 15
        b"\x93\xa9\xf0\x00"
        # sltui x20, x1, 15
        b"\x13\xba\xf0\x00"
    )

    file.write(buf)