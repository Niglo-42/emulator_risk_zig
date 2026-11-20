// "Finisher" : un tout petit périphérique qui permet au programme invité
// d'arrêter la machine en donnant un code de sortie.
// Même adresse et même protocole que le périphérique "sifive,test0" de
// QEMU virt (0x100000), ce qui servira deux fois :
//   - aux tests riscv-tests (PASS / FAIL)
//   - à Linux plus tard, pour poweroff / reboot (syscon dans le device tree)
//
// Protocole : le guest écrit un mot de 32 bits à 0x100000
//   0x5555                  -> arrêt, succès (code 0)
//   0x3333 | (code << 16)   -> arrêt, échec avec `code`
//   0x7777                  -> reboot (on se contente d'arrêter)

const std = @import("std");
const main = @import("main.zig");

pub const BASE: u32 = 0x100000;

pub const FINISHER_PASS: u32 = 0x5555;
pub const FINISHER_FAIL: u32 = 0x3333;
pub const FINISHER_RESET: u32 = 0x7777;

// null tant que personne n'a demandé l'arrêt
pub var exit_code: ?u8 = null;

pub fn write(value: u32) void {
    const command = value & 0xffff;
    const code: u32 = value >> 16;
    if (command == FINISHER_PASS) {
        exit_code = 0;
    } else if (command == FINISHER_FAIL) {
        // un code de 0 en échec serait trompeur : on force au moins 1
        exit_code = if (code == 0) 1 else @truncate(@min(code, 255));
    } else if (command == FINISHER_RESET) {
        std.debug.print("reboot demandé par le guest : arrêt\n", .{});
        exit_code = 0;
    } else {
        // valeur inconnue : on ignore, comme le vrai périphérique
        return;
    }
    // le CPU (et la fenêtre) s'arrêtent au prochain tour de boucle
    main.flag.store(true, .monotonic);
}
