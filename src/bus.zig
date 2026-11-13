const std = @import("std");
const print = std.debug.print;
const def_reg = @import("data/define_regs.zig");
const sys = @import("syscall.zig");
const uart = @import("uart.zig");
const Err = error{
    Byte_Size_Err,
    BadAdress,
    UartBadByteSize,
    UartBadOffset,
};

pub var regs: [32]u32 = @splat(0);
pub const RAM_BASE = 0x80000000;

pub const Perif = struct {
    debug: [0xf00]u8,
    ram: [0x100000]u8, // 1mo
    // virt_test: [0x1000]u8,
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
    // .virt_test = @splat(0),
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
};

pub fn get_addr(addr: u32, byte_nb: u32) !struct { u32, []u8, kind } {
    switch (addr) {
        0x100...0xfff => {},
        0x10000000...0x10000007 => {},
        0x80000000...0x800fffff => {},
        else => {
            return Err.BadAdress;
        },
    }
    const base: u32, const mem: []u8, const t: kind = switch (addr + byte_nb - 1) {
        0x100...0xfff => .{ 0, perif.debug[0..], kind.DEBUG },
        0x10000000...0x10000fff => .{ 0x10000000, uart.uart.passiv_regs[0..], kind.UART },
        0x80000000...0x800fffff => .{ 0x80000000, perif.ram[0..], kind.RAM },
        else => return Err.BadAdress,
    };
    const offset = addr - base;
    if (t == kind.UART) {
        if (byte_nb != 1) {
            return Err.UartBadByteSize;
        }
        if (offset > 7) {
            return Err.UartBadOffset;
        }
    }
    return .{ offset, mem, t };
}

pub fn fetch_mem(addr: u32, byte_size: u32) !u32 {
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
    if (t != kind.UART) {
        for (0..byte_size) |i| {
            const shift: u5 = @intCast(i * 8);
            mem[offset + i] = @truncate(value >> shift);
        }
    } else {
        const offsetu3: u3 = @truncate(offset);
        const byte: u8 = @truncate(value);
        uart.uart.setter(offsetu3, byte);
    }
}
