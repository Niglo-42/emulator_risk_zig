fn log2(unicode: u32) u5 {
    var res: u5 = 1;
    if (unicode == 0) {
        return res;
    }
    while (unicode >> res > 0) {
        res += 1;
    }
    return res;
}

// const Err = error {Utf8RangeFault,};

pub fn encode_utf8(data: i32, buf: *[4]u8) u3 {
    // 0xD800
    // Début de la plage des surrogate UTF-16
    // 0xDFFF
    // Fin de la plage des surrogate
    // 0x110000
    // Au-delà de la limite Unicode
    if (data >= 0x110000 or (data >= 0xd800 and data <= 0xdfff)) {
        return 0;
    }
    const uni: u32 = @bitCast(data);
    const unicode: u21 = @truncate(uni);
    const bit_required: u5 = log2(uni);
    return switch (bit_required) {
        0...7 => {
            buf[0] = @truncate(unicode & 0x7f);
            return 1;
        },
        8...11 => {
            const x: u6 = @truncate(unicode);
            const y: u5 = @truncate(unicode >> 6);
            buf[0] = 0b10 << 6 | @as(u8, x);
            buf[1] = 0b110 << 5 | @as(u8, y);
            return 2;
        },
        12...16 => {
            const x: u6 = @truncate(unicode);
            const y: u6 = @truncate(unicode >> 6);
            const z: u4 = @truncate(unicode >> 12);
            buf[0] = 0b10 << 6 | @as(u8, x);
            buf[1] = 0b10 << 6 | @as(u8, y);
            buf[2] = 0b1110 << 4 | @as(u8, z);
            return 3;
        },
        17...21 => {
            const x: u6 = @truncate(unicode);
            const y: u6 = @truncate(unicode >> 6);
            const z: u6 = @truncate(unicode >> 12);
            const w: u3 = @truncate(unicode >> 18);
            buf[0] = 0b10 << 6 | @as(u8, x);
            buf[1] = 0b10 << 6 | @as(u8, y);
            buf[2] = 0b10 << 6 | @as(u8, z);
            buf[3] = 0b11110 << 3 | @as(u8, w);
            return 4;
        },
        else => {return 0;},
    };
}