morceaux = [
    # 0000: addi x15, x0, 1024
    b"\x93\x07\x00\x40",
    # 0004: addi x14, x0, 1
    b"\x13\x07\x10\x00",
    # 0008: lui x1, 0x80000
    b"\xb7\x00\x00\x80",
    # 000c: lui x2, 0x80000
    b"\x37\x01\x00\x80",
    # 0010: addi x2, x2, -1
    b"\x13\x01\xf1\xff",
    # 0014: addi x3, x0, -1
    b"\x93\x01\xf0\xff",
    # 0018: sb x14, 0(x15)
    b"\x23\x80\xe7\x00",
    # 001c: blt x1, x2, +8
    b"\x63\xc4\x20\x00",
    # 0020: sb x0, 0(x15)
    b"\x23\x80\x07\x00",
    # 0024: bltu x1, x2, +8
    b"\x63\xe4\x20\x00",
    # 0028: sb x14, 1(x15)
    b"\xa3\x80\xe7\x00",
    # 002c: bge x1, x2, +8
    b"\x63\xd4\x20\x00",
    # 0030: sb x14, 2(x15)
    b"\x23\x81\xe7\x00",
    # 0034: sb x14, 3(x15)
    b"\xa3\x81\xe7\x00",
    # 0038: bgeu x1, x2, +8
    b"\x63\xf4\x20\x00",
    # 003c: sb x0, 3(x15)
    b"\xa3\x81\x07\x00",
    # 0040: sb x14, 4(x15)
    b"\x23\x82\xe7\x00",
    # 0044: bge x1, x1, +8
    b"\x63\xd4\x10\x00",
    # 0048: sb x0, 4(x15)
    b"\x23\x82\x07\x00",
    # 004c: blt x2, x2, +8
    b"\x63\x44\x21\x00",
    # 0050: sb x14, 5(x15)
    b"\xa3\x82\xe7\x00",
    # 0054: sb x14, 6(x15)
    b"\x23\x83\xe7\x00",
    # 0058: bne x14, x0, +4092
    b"\xe3\x1e\x07\x7e",
    # 005c: sb x0, 6(x15)
    b"\x23\x83\x07\x00",
    # 0060: 1020 x addi x0, x0, 0
    b"\x13\x00\x00\x00" * 1020,
    # 1050: sb x0, 6(x15)
    b"\x23\x83\x07\x00",
    # 1054: addi x7, x0, 2
    b"\x93\x03\x20\x00",
    # 1058: addi x5, x5, 1
    b"\x93\x82\x12\x00",
    # 105c: 1022 x addi x0, x0, 0
    b"\x13\x00\x00\x00" * 1022,
    # 2054: addi x6, x6, 1
    b"\x13\x03\x13\x00",
    # 2058: bne x6, x7, -4096
    b"\x63\x10\x73\x80",
    # 205c: sb x5, 7(x15)
    b"\xa3\x83\x57\x00",
    # 2060: sb x14, 8(x15)
    b"\x23\x84\xe7\x00",
    # 2064: jal x12, +4096
    b"\x6f\x16\x00\x00",
    # 2068: sb x0, 8(x15)
    b"\x23\x84\x07\x00",
    # 206c: 1021 x addi x0, x0, 0
    b"\x13\x00\x00\x00" * 1021,
    # 3060: sb x0, 8(x15)
    b"\x23\x84\x07\x00",
    # 3064: jal x0, +16
    b"\x6f\x00\x00\x01",
    # 3068: jalr x0, 0(x12)
    b"\x67\x00\x06\x00",
    # 306c: sb x14, 9(x15)
    b"\xa3\x84\xe7\x00",
    # 3070: jalr x0, 0(x12)
    b"\x67\x00\x06\x00",
    # 3074: 1022 x addi x0, x0, 0
    b"\x13\x00\x00\x00" * 1022,
    # 406c: jal x12, -4096
    b"\x6f\xf6\x0f\x80",
    # 4070: sb x14, 10(x15)
    b"\x23\x85\xe7\x00",
    # 4074: sb x14, 11(x15)
    b"\xa3\x85\xe7\x00",
    # 4078: auipc x5, 0x0
    b"\x97\x02\x00\x00",
    # 407c: addi x5, x5, 16
    b"\x93\x82\x02\x01",
    # 4080: jalr x5, 0(x5)
    b"\xe7\x82\x02\x00",
    # 4084: sb x0, 11(x15)
    b"\xa3\x85\x07\x00",
    # 4088: sb x14, 12(x15)
    b"\x23\x86\xe7\x00",
    # 408c: auipc x5, 0x0
    b"\x97\x02\x00\x00",
    # 4090: addi x5, x5, 24
    b"\x93\x82\x82\x01",
    # 4094: jalr x0, -8(x5)
    b"\x67\x80\x82\xff",
    # 4098: sb x0, 12(x15)
    b"\x23\x86\x07\x00",
    # 409c: lui x0, 0xfffff
    b"\x37\xf0\xff\xff",
    # 40a0: auipc x0, 0x1
    b"\x17\x10\x00\x00",
    # 40a4: sub x0, x3, x1
    b"\x33\x80\x11\x40",
    # 40a8: xori x0, x3, -1
    b"\x13\xc0\xf1\xff",
    # 40ac: sltiu x6, x0, 1
    b"\x13\x33\x10\x00",
    # 40b0: sb x6, 13(x15)
    b"\xa3\x86\x67\x00",
    # 40b4: addi x6, x0, 1543
    b"\x13\x03\x70\x60",
    # 40b8: add x6, x6, x6
    b"\x33\x03\x63\x00",
    # 40bc: addi x7, x0, 128
    b"\x93\x03\x00\x08",
    # 40c0: sb x7, -2048(x6)
    b"\x23\x00\x73\x80",
    # 40c4: addi x8, x0, -1008
    b"\x13\x04\x00\xc1",
    # 40c8: sb x3, 2047(x8)
    b"\xa3\x0f\x34\x7e",
    # 40cc: addi x4, x0, 33
    b"\x13\x02\x10\x02",
    # 40d0: addi x5, x2, 0
    b"\x93\x02\x01\x00",
    # 40d4: add x5, x5, x5
    b"\xb3\x82\x52\x00",
    # 40d8: sub x6, x2, x1
    b"\x33\x03\x11\x40",
    # 40dc: sll x7, x3, x4
    b"\xb3\x93\x41\x00",
    # 40e0: srl x8, x1, x4
    b"\x33\xd4\x40\x00",
    # 40e4: sra x9, x1, x4
    b"\xb3\xd4\x40\x40",
    # 40e8: slt x10, x1, x2
    b"\x33\xa5\x20\x00",
    # 40ec: sltu x11, x2, x1
    b"\xb3\x35\x11\x00",
    # 40f0: sltiu x12, x2, -1
    b"\x13\x36\xf1\xff",
    # 40f4: andi x13, x1, -16
    b"\x93\xf6\x00\xff",
    # 40f8: srai x4, x1, 31
    b"\x13\xd2\xf0\x41",
    # 40fc: auipc x3, 0x80000
    b"\x97\x01\x00\x80",
    # 4100: lb x1, 15(x15)
    b"\x83\x80\xf7\x00",
    # 4104: lbu x2, 14(x15)
    b"\x03\xc1\xe7\x00",
    # 4108: lh x14, 14(x15)
    b"\x03\x97\xe7\x00",
]

programme = b"".join(morceaux)

assert len(programme) == 16652, len(programme)
with open("bin.bin", "wb") as f:
    f.write(programme)
print(len(programme), "octets ecrits dans test_final.bin")
