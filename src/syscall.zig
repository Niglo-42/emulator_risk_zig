const std = @import("std");
const print = std.debug.print;
const bus = @import("bus.zig");

pub fn syscall6(
    number: u32,
    arg1: anytype,
    arg2: anytype,
    arg3: anytype,
    arg4: anytype,
    arg5: anytype,
    arg6: anytype,
) u32 {
    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u32),
        : [number] "{rax}" (number),
          [arg1] "{rdi}" (arg1),
          [arg2] "{rsi}" (arg2),
          [arg3] "{rdx}" (arg3),
          [arg4] "{r10}" (arg4),
          [arg5] "{r8}" (arg5),
          [arg6] "{r9}" (arg6),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

const Err = enum {
    SYSCALL_UNSUPPORTED,
};

pub fn translate(number: u32) !u32 {
    // if (number >= RISCV_TO_X64.len)
    //     return Err.SYSCALL_UNSUPPORTED;

    const host_number = RISCV_TO_X64[number];

    // if (host_number == SYSCALL_UNSUPPORTED)
    //     return Err.SYSCALL_UNSUPPORTED;

    return @as(u32, host_number);
}

pub const SYSCALL_UNSUPPORTED: u16 = 0xFFFF;

pub fn read_flags(flags: u16, regs: *[32]u32) void {
    if (flags == 0xffff) {
        return;
    }
    const ram_addr: u32 = @truncate(@intFromPtr(&bus.perif.ram));
    for (10..16, 1..) |bit, i| {
        const shr: u4 = @truncate(bit);
        if ((flags >> shr) & 1 == 1) {
            regs[16 - i] += ram_addr;
        } // 0x4001
        // 0b0100_00.00_0000_0000
    }
}

pub const RISCV_TO_X64: [500]u16 = .{
    // 000..009
    16590,  207,    8401,   24786,  6352,   57532,  57533,  24766,  57535,  57536,
    // 010..019
    24769,  49346,  49347,  16580,  49349,  49350,  16583,  32847,  0xffff, 290,
    // 020..029
    291,    4329,   18713,  32,     292,    72,     294,    16638,  255,    16,
    // 030..039
    251,    252,    73,     16643,  16642,  16647,  41226,  20745,  0xffff, 32934,
    // 040..049
    59557,  49307,  0xffff, 49289,  16522,  32844,  77,     285,    16653,  32848,
    // 050..059
    81,     32929,  91,     16652,  16644,  93,     16641,  3,      153,    33061,
    // 060..069
    20659,  16601,  8,      16384,  16385,  16403,  16404,  16401,  16402,  16679,
    // 070..079
    16680,  8232,   32014,  45327,  16673,  16662,  20755,  276,    24843,  24838,
    // 080..089
    16389,  162,    74,     75,     277,    283,    12574,  16671,  24856,  32931,
    // 090..099
    49277,  49278,  135,    60,     231,    10487,  32986,  272,    39114,  33041,
    // 100..109
    24850,  49187,  16420,  24614,  8438,   41135,  32944,  24798,  16608,  225,
    // 110..119
    12511,  226,    16611,  16612,  16613,  12518,  16487,  101,    16526,  8336,
    // 120..129
    145,    16527,  8395,   8396,   24,     146,    147,    16532,  219,    62,
    // 130..139
    200,    234,    49283,  32898,  24589,  24590,  32895,  57472,  8321,   15,
    // 140..149
    141,    140,    4265,   114,    106,    113,    105,    117,    57462,  119,
    // 150..159
    57464,  122,    123,    32868,  109,    121,    124,    112,    16499,  16500,
    // 160..169
    32831,  32938,  32939,  16481,  16544,  16482,  95,     157,    57653,  49248,
    // 170..179
    49316,  32927,  39,     110,    102,    107,    104,    108,    186,    32867,
    // 180..189
    37104,  33009,  18674,  22771,  16628,  24821,  68,     8263,   16454,  16453,
    // 190..199
    64,     66,     20700,  16449,  29,     8223,   16414,  32835,  41,     4149,
    // 200..209
    16433,  50,     24619,  16426,  24627,  24628,  18476,  19501,  4150,   6199,
    // 210..219
    48,     16430,  16431,  187,    12,     11,     25,     57592,  57593,  250,
    // 220..229
    12344,  57403,  9,      221,    32935,  32936,  10,     26,     149,    150,
    // 230..239
    151,    152,    8219,   28,     216,    4333,   49391,  16622,  12544,  14615,
    // 240..249
    4393,   33066,  24864,  18731,  0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 250..259
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 260..269
    20541,  12590,  300,    2349,   28975,  16688,  16689,  306,    308,    16691,
    // 270..279
    20790,  20791,  312,    16697,  16698,  16699,  20796,  8509,   33086,  33087,
    // 280..289
    20801,  28994,  323,    324,    325,    20806,  16711,  16712,  329,    330,
    // 290..299
    331,    18764,  7501,   33102,  4416,   0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 300..309
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 310..319
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 320..329
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 330..339
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 340..349
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 350..359
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 360..369
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 370..379
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 380..389
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 390..399
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 400..409
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 410..419
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 420..429
    0xffff, 0xffff, 0xffff, 0xffff, 8616,   16809,  2474,   8619,   16812,  20909,
    // 430..439
    33198,  12719,  432,    16817,  434,    33203,  436,    25013,  438,    16823,
    // 440..449
    16824,  22969,  20922,  4539,   33212,  8637,   446,    447,    448,    37313,
    // 450..459
    450,    25027,  16836,  453,    33222,  35271,  33224,  49609,  49610,  25035,
    // 460..469
    16844,  49613,  462,    22991,  22992,  20945,  20946,  20947,  25044,  25045,
    // 470..479
    49622,  471,    472,    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 480..489
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
    // 490..499
    0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff, 0xffff,
};
