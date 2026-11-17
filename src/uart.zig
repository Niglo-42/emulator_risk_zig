const std = @import("std");

pub const Err = error{
    WriteImpossible,
    NothingToRead,
};

pub var uart = ring_buffer.init();
const CAP = 128;

const ring_buffer = struct {
    queue: [CAP]u8,
    passiv_regs: [8]u8,
    read_h: std.atomic.Value(usize),
    write_h: std.atomic.Value(usize),

    fn init() ring_buffer {
        var x = ring_buffer{
            .queue = @splat(0),
            .passiv_regs = @splat(0),
            .read_h = std.atomic.Value(usize).init(0),
            .write_h = std.atomic.Value(usize).init(0),
        };
        x.passiv_regs[5] = 0x60;
        return x;
    }

    pub fn getter(self: *ring_buffer, offset: u3) ?u8 {
        // 0 on fait lire le guest, 5 -> get flag, else get any flag
        switch (offset) {
            0 => {
                return self.guest_read();
            },
            5 => {
                if (self.read_h.load(.monotonic) == self.write_h.load(.monotonic)) {return 0x60;}
                else {return 0x61;}
            },
            else => {
                return self.passiv_regs[offset];
            },
        }
    }

    pub fn setter(self: *ring_buffer, offset: u3, byte: u8) void {
        // 0 -> write sur stdout, 5 -> push byte in data reg uart
        switch (offset) {
            0 => {
                const ptr: [*]const u8 = @ptrCast(&byte);
                _ = std.os.linux.write(1, ptr, 1);
            },
            5 => {},
            else => {
                self.passiv_regs[offset] = byte;
            },
        }
    }

    pub fn host_write(self: *ring_buffer, val: u8) i8 {
        const w = self.write_h.load(.monotonic);
        const r = self.read_h.load(.acquire);
        const res: u8 = @truncate(CAP - (w - r));
        if ( res == 0) {
            return -1;
        }
        self.queue[w & (CAP - 1)] = val;
        self.write_h.store(w +% 1, .release);
        // self.passiv_regs[5] |= 1; RELICAT
        return @bitCast(res - 1);
    }

    // quand invité lit à uart offset 0 cela est comme une instruction
    // qui déclanche cette fonction. (pour simuler la vrai transaction)
    pub fn guest_read(self: *ring_buffer) ?u8 { 
        const r = self.read_h.load(.monotonic);
        const w = self.write_h.load(.acquire);
        if (w == r) {return null;}
        const res = self.queue[r & (CAP - 1)];
        self.read_h.store(r +% 1, .release);
        // if (self.read_h == self.write_h) {
        //     self.passiv_regs[5] &= 0xfe; // RELICAT
        // }
        return res;
    }
};

test "test uart" {
    _ = uart.host_write(170) catch 255;
    _ = uart.host_write(0xBB) catch 255;
    _ = uart.host_write(0xCC) catch 255;
    var buf: [3]?u8 = undefined;
    buf[0] = uart.guest_read();
    buf[1] = uart.guest_read();
    buf[2] = uart.guest_read();
    try std.testing.expectEqual(170, buf[0]);
    try std.testing.expectEqual(0xBB, buf[1]);
    try std.testing.expectEqual(0xCC, buf[2]);
    buf[0] = uart.guest_read();
    try std.testing.expectEqual(null, buf[0]);
    for (0..129) |i| {
        const x: u8 = @truncate(i);
        const remaining_size = uart.host_write(x) catch 255;
        // 127 - 128 = 127 + 128 car - = neg (not + 1)
        try std.testing.expectEqual(127 -% x, remaining_size);
    }
    for (0..129) |i| {
        const x: u8 = @truncate(i);
        if (x == 128) {
            try std.testing.expectEqual(null, uart.guest_read());
        } else {
            try std.testing.expectEqual(x, uart.guest_read());
        }
    }
    _ = uart.host_write(0x62) catch 255; // on met 0x62 dans file vide

    const something_to_read = uart.getter(5);
    // donc on a quelque chose à lire
    try std.testing.expectEqual(0x61, something_to_read);
    const b = uart.getter(0); // on lit et vide la file
    try std.testing.expectEqual(0x62, b);
    const something_to_read2 = uart.getter(5); // quelque chose à lire ?
    try std.testing.expectEqual(0x60, something_to_read2);
    // non car vide donc bit 0 à 0 au lieu de 1.

}
