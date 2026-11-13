const print_err = @import("data/errors.zig");
const fetch = @import("fetch_and_decode.zig");
const bus = @import("bus.zig");

pub fn bytes_reader(buffer: []u8) u32 {
    var result: u32 = 0;
    for (0..buffer.len) |i| {
        const shift: u5 = @intCast(i * 8);
        const res = @as(u32, buffer[i]);
        result |= res << shift;
    }
    return result;
}

pub fn parse_elf(buffer: []u8) ![]struct { u32, u32 } {
    if (buffer.len < 52) {
        try print_err.error_handeling(
            @truncate(buffer.len),
            52,
            "header_too_short",
        );
    }
    // for (buffer[0..52], 0..52) |byte, i| {
    //     print("#{d:>2}: {x:>2}\n", .{ i, byte });
    // }
    const magic = [_]u8{ 0x7f, 0x45, 0x4c, 0x46 };

    for (buffer[0..4], magic) |byte, cmp| {
        if (byte != cmp) {
            try print_err.error_handeling(
                @as(u32, byte),
                @as(u32, cmp),

                "wrong_magic",
            );
        }
    }
    for (buffer[4..7]) |byte| {
        if (byte != 1) {
            try print_err.error_handeling(
                @as(u32, byte),
                @as(u32, 1),

                "wrong_oct 4..7",
            );
        }
    }
    if (bytes_reader(buffer[18..20]) != 0xf3) { // if risk_v 243[base10]
        try print_err.error_handeling(
            bytes_reader(buffer[18..20]),
            @as(u32, 243),

            "wrong_machine",
        );
    }

    if (bytes_reader(buffer[20..24]) != 1) { // if risk_v I !
        try print_err.error_handeling(
            bytes_reader(buffer[20..24]),
            1,

            "wrong_machine_type",
        );
    }
    const entry = bytes_reader(buffer[24..28]);
    if (entry >= bus.perif.ram.len + bus.RAM_BASE) {
        try print_err.error_handeling(
            entry,
            0x80000000,

            "entry out of bound",
        );
    } else {
        fetch.pc = entry;
    }

    // const e_shoff = bytes_reader(buffer[32..36]);
    const e_flags = bytes_reader(buffer[36..40]);
    const e_ehsize = bytes_reader(buffer[40..42]);
    //s = section et p = programe
    // où ça commence, la taille d'un élément, nb_elem
    const e_phoff = bytes_reader(buffer[28..32]);
    const e_phentsize = bytes_reader(buffer[42..44]);
    const e_phnum = bytes_reader(buffer[44..46]);
    // const e_shentsize = bytes_reader(buffer[46.48]);
    // const e_shnum = bytes_reader(buffer[48..50]);
    // const e_shstrndx = bytes_reader(buffer[50..52]);

    if (e_phoff != 52) {
        try print_err.error_handeling(
            e_phoff,
            52,

            "bad_program_header_offset",
        );
    }

    if (e_flags != 0) {
        try print_err.error_handeling(
            e_flags,
            0,

            "wrong_flag",
        );
    }

    if (e_phentsize != 32) {
        try print_err.error_handeling(
            e_phentsize,
            32,

            "wrong_phentsize",
        );
    }

    if (e_ehsize != 52) {
        try print_err.error_handeling(
            e_ehsize,
            52,

            "wrong_ehsize",
        );
    }
    if (e_phnum == 0) {
        try print_err.error_handeling(
            e_phnum,
            1,

            "wrong_phnum",
        );
    }
    var res: [0x1000]struct { u32, u32 } = undefined;
    for (0..e_phnum) |i| {
        const p_h = prog_header.init(buffer[e_phoff + i * e_phentsize ..][0..32]);
        if (p_h.p_type != 1) {
            continue;
        }

        if (p_h.p_memsz == 0) {
            continue;
        }
        if (p_h.p_filesz > p_h.p_memsz) {
            try print_err.error_handeling(
                p_h.p_filesz,
                1,

                "file image has to < memory image",
            );
        }
        if (p_h.p_paddr + p_h.p_memsz > bus.perif.ram.len + bus.RAM_BASE) {
            try print_err.error_handeling(
                p_h.p_paddr + p_h.p_memsz,
                bus.perif.ram.len - 1 + bus.RAM_BASE,

                "out of ram !",
            );
        }
        if (p_h.p_paddr < bus.RAM_BASE) {
            try print_err.error_handeling(
                p_h.p_paddr,
                bus.RAM_BASE,
                "out of ram !",
            );
        }
        const dest = p_h.p_paddr - bus.RAM_BASE;
        @memcpy(bus.perif.ram[dest .. dest + p_h.p_filesz], buffer[p_h.p_offset .. p_h.p_offset + p_h.p_filesz]);
        @memset(bus.perif.ram[dest + p_h.p_filesz .. dest + p_h.p_memsz], 0);
        res[i] = .{ p_h.p_filesz - dest, p_h.p_memsz - dest };
        // todo verif si entry est dedans
    }
    return res[0..e_phnum];
}

const prog_header = struct {
    p_type: u32,
    p_offset: u32,
    p_vaddr: u32,
    p_paddr: u32,
    p_filesz: u32,
    p_memsz: u32,
    p_flags: u32,
    p_align: u32,

    fn init(buffer: *[32]u8) prog_header {
        return prog_header{
            .p_type = bytes_reader(buffer[0..4]),
            .p_offset = bytes_reader(buffer[4..8]),
            .p_vaddr = bytes_reader(buffer[8..12]),
            .p_paddr = bytes_reader(buffer[12..16]),
            .p_filesz = bytes_reader(buffer[16..20]),
            .p_memsz = bytes_reader(buffer[20..24]),
            .p_flags = bytes_reader(buffer[24..28]),
            .p_align = bytes_reader(buffer[28..32]),
        };
    }
};
