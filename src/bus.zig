const std = @import("std");
const print = std.debug.print;
const def_reg = @import("data/define_regs.zig");
const sys = @import("syscall.zig");
const uart = @import("uart.zig");
const screen = @import("screen.zig");
const utf8 = @import("utf_8.zig");
const Err = error{
    Byte_Size_Err,
    BadAdress,
    UartBadByteSize,
    UartBadOffset,
};

pub const privilege: u2 = 3;
pub var regs: [32]u32 = @splat(0);
pub const RAM_BASE = 0x80000000;
pub var csr: [0x1000]u8 = @splat(0);
// l'index d'un csr transporte des métadonnées
// si bit 11 allumé alors c'est une const
// bit 9 et 8 = (00: u, 01: s, 11:m) les privileges
// u = user et m = machine

// mvendorid 0xF11,
// marchid 0xF12,
// mimpid 0xF13 : 0, ce qui veut dire « non renseigné ».
// mhartid 0xF14 : 0, puisque tu as un seul cœur.

// commence à s'eloigner de bus donc faire un nouveau fichier csr
// config (description de la machine):
// misa 0x301 : l’architecture et les extensions présentes.
// Bits 31:30 = 01 pour 32 bits.
// Ensuite, un bit par lettre : A = bit 0, I = bit 8,
//  M = bit 12, S = bit 18, U = bit 20.
// Pour RV32IMA avec le mode U, ça donne 0x40101101.
//  N’active le bit A que quand A sera vraiment implémentée.
// Les écritures sont ignorées.
// mstatus 0x300 : l’état global. En M + U,
//  seuls trois champs existent :
// MIE, bit 3 : interruptions autorisées globalement ;
// MPIE, bit 7 : la valeur de MIE avant le trap ;
// MPP, bits 12:11 : le privilège avant le trap.
//  Seules les valeurs 00 et 11 sont légales ;
//  si on écrit 01 ou 10, ramène à une valeur légale.
// Tous les autres bits se lisent à 0 et ignorent
//  les écritures : c’est un masque d’écriture.

//TODO implémente les configs des 15 regs de csr
// ajoute aussi les 4 regs de cycle puis test.
// les instructions sont faites et branchées, et ça compile
// git push fait, tu en es à 1h de travail, à ajouter à cette
// deuxieme partie.

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
        0x1000...0x1000fff => {},
        0x10000000...0x10000007 => {},
        0x80000000...0x800fffff => {},
        else => {
            return Err.BadAdress;
        },
    }
    const base: u32, const mem: []u8, const t: kind = switch (addr + byte_nb - 1) {
        0x100...0xfff => .{ 0x100, perif.debug[0..], kind.DEBUG },
        0x1000...0x1000fff => .{ 0x1000, screen.screen.view[0..], kind.SCREEN },
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
    if (t == kind.UART) {
        const offsetu3: u3 = @truncate(offset);
        uart.uart.setter(offsetu3, @truncate(value));
    } else {
        for (0..byte_size) |i| {
            const shift: u5 = @intCast(i * 8);
            mem[offset + i] = @truncate(value >> shift);
        }
    }
}
