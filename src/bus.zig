const std = @import("std");
const print = std.debug.print;
const def_reg = @import("data/define_regs.zig");
const sys = @import("syscall.zig");
const uart = @import("uart.zig");
const screen = @import("screen.zig");
const utf8 = @import("utf_8.zig");
const finisher = @import("finisher.zig");
const Err = error{
    Byte_Size_Err,
    BadAdress,
    UartBadByteSize,
    UartBadOffset,
    FinisherBadAccess,
};


pub var regs: [32]u32 = @splat(0);
pub const RAM_BASE = 0x80000000;
pub const SCREEN_BASE = 0x40000000;


pub const Perif = struct {
    debug: [0xf00]u8,
    ram: [0x100000]u8, // 1mo
    time: [0x1000]u8,
    clint: [0x10000]u8,
    // Pio: [0x10000]u8,
    // virt_plic: [0x1000]u8,
    // uart: [0x1000]u8,
    // mmio: [0x1000]u8,
    // pcie_ecam: [0x1000]u8,
    // pcie_mmio: [0x1000]u8,
};

pub var perif: Perif = .{
    .debug = @splat(0),
    .ram = @splat(0),
    .time = @splat(0),
    .clint = @splat(0),
    // .Pio = @splat(0),
    // .virt_plic = @splat(0),
    // .uart = @splat(0),
    // .mmio = @splat(0),
    // .pcie_ecam = @splat(0),
    // .pcie_mmio = @splat(0),
};

pub const kind = enum {
    DEBUG,
    UART,
    RAM,
    SCREEN,
    FINISHER,
};

pub fn array2u32(buf: [4]u8) u32 {
    return @as(u32, buf[0]) | @as(u32, buf[1]) << 8 | @as(u32, buf[2]) << 16 | @as(u32, buf[3]) << 24;
}

pub fn u32toarray(data: u32, buf: *[4]u8) void {
    for (0..4) |i| {
        const shr: u5 = @truncate(i << 3);
        buf[i] = @truncate(data >> shr);
    }
}

pub fn get_addr(addr: u32, byte_nb: u32) !struct { u32, []u8, kind } {
    // verifie si addr commence dans une plage connu sinon segfault
    // pareil pour addr + taille de la data
    // return l'adress host et déduit l'offset réélement demandé
    // si uart alors check flux == 1  byte
    switch (addr) {
        0x100...0xfff => {},
        0x100000...0x100fff => {},
        0x40000000...0x40ffffff => {},
        0x10000000...0x10000007 => {},
        0x80000000...0x800fffff => {},
        else => {
            return Err.BadAdress;
        },
    }
    const base: u32, const mem: []u8, const t: kind = switch (addr + byte_nb - 1) {
        0x100...0xfff => .{ 0x100, perif.debug[0..], kind.DEBUG },
        // framebuffer de 16 Mo, déplacé de 0x1000 à 0x40000000 : à 0x1000 il
        // recouvrait toute la zone basse (finisher à 0x100000, CLINT à 0x2000000)
        0x40000000...0x40ffffff => .{ SCREEN_BASE, screen.screen.view[0..], kind.SCREEN },
        // le finisher n'a pas de mémoire à lui : on passe un slice vide
        0x100000...0x100fff => .{ finisher.BASE, &[_]u8{}, kind.FINISHER },
        0x10000000...0x10000007 => .{ 0x10000000, uart.uart.passiv_regs[0..], kind.UART },
        0x80000000...0x800fffff => .{ 0x80000000, perif.ram[0..], kind.RAM },
        else => return Err.BadAdress,
    };
    const offset = addr - base;
    if (t == kind.UART) {
        if (byte_nb != 1) {
            return Err.UartBadByteSize;
        }
    }
    if (t == kind.FINISHER) {
        // on n'accepte qu'un mot de 32 bits à l'offset 0
        if (byte_nb != 4 or offset != 0) {
            return Err.FinisherBadAccess;
        }
    }
    return .{ offset, mem, t };
}

pub fn fetch_mem(addr: u32, byte_size: u32) !u32 {
    // si mem classique alors packing de la data en little endian
    // si uart, use getter
    if (byte_size != 1 and byte_size != 2 and byte_size != 4) {
        return Err.Byte_Size_Err;
    }
    const offset: u32, const mem: []u8, const t: kind = try get_addr(addr, byte_size);
    var data: u32 = 0;
    if (t == kind.FINISHER) {
        // le finisher se relit à 0
        return 0;
    }
    if (t != kind.UART) {
        for (0..byte_size) |i| {
            const shift: u5 = @truncate(i * 8);
            data |= @as(u32, mem[offset + i]) << shift;
        }
    } else {
        const offsetu3: u3 = @truncate(offset);
        const byte_from_uart = uart.uart.getter(offsetu3) orelse 0;
        data = @as(u32, byte_from_uart);
    }
    return data;
}

pub fn store_mem(addr: u32, byte_size: u32, value: u32) !void {
    if (byte_size != 1 and byte_size != 2 and byte_size != 4) {
        return Err.Byte_Size_Err;
    }
    const offset: u32, const mem: []u8, const t: kind = try get_addr(addr, byte_size);
    if (t == kind.FINISHER) {
        finisher.write(value);
    } else if (t == kind.UART) {
        const offsetu3: u3 = @truncate(offset);
        uart.uart.setter(offsetu3, @truncate(value));
    } else {
        for (0..byte_size) |i| {
            const shift: u5 = @intCast(i * 8);
            mem[offset + i] = @truncate(value >> shift);
        }
    }
}
