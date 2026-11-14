const std = @import("std");
const uart = @import("uart.zig");
const linux = std.os.linux;
const posix = std.posix;
const STDOUT_FILENO = posix.STDOUT_FILENO;
const STDIN_FILENO = posix.STDIN_FILENO;
const main = @import("main.zig");

const Err = error {
    Fail2Read,
    NotaTerminal,
};

pub fn enableRawMode() !struct{linux.termios, linux.termios} {
    const orig_termios = try posix.tcgetattr(STDIN_FILENO);
    var termios = orig_termios;
    if (try main.stdout.isTty(main.io.io)) {
    termios.lflag.ECHO = false;
    termios.lflag.ICANON = false;
    termios.iflag.IXON = false; // disable Ctrl-S and Ctrl-Q signals
    termios.lflag.IEXTEN = false; // disable Ctrl-V
    // termios.oflag.OPOST = false; // disable the famous \r before the \n

    termios.iflag.INPCK = false; // disable parity checking (obsolete?)
    termios.iflag.ISTRIP = false; // disable stripping of 8th bit
    termios.cflag.CSIZE = .CS8; // set character size to 8 bits
    // Set read timeouts
    termios.cc[@intFromEnum(linux.V.MIN)] = 0; // Return immediately when any bytes are available
    termios.cc[@intFromEnum(linux.V.TIME)] = 0; // Wait up to 0 seconds for input
    posix.tcsetattr(STDIN_FILENO, .FLUSH, termios) catch @panic("Disabling raw mode failed!");
    }
    return .{orig_termios, termios};
}

/// Disable terminal raw mode by restoring the saved configuration.
pub fn disableRawMode(orig_termios: linux.termios) void {
    posix.tcsetattr(STDIN_FILENO, .FLUSH, orig_termios) catch @panic("Disabling raw mode failed!");
}

pub fn serve_the_world() !void {
    var buf: [4]u8 = undefined;
    const n = linux.read(0, &buf, 4);
    if (n > 4) {
        return Err.Fail2Read;
    }
    const nb = @min(n, 4);
    for (0..nb) |i| {
        _ = try uart.uart.host_write(buf[i]);
    }
}


// Ton main est correct pour deux cas : le retour normal
//  et les erreurs remontées par try. Dans les deux, le defer restaure le 
//  terminal. Mais trois sorties le contournent.

// L’exit de l’invité. Ton start.s finit par un ecall de sortie, que ta table
//  traduit en appel système hôte. Le processus meurt sur place, sans exécuter
//   le defer. C’est le cas le plus courant : chaque programme invité qui se termine
//    normalement laisse ton shell en mode brut. La solution propre est que la sortie
//     de l’invité ne tue pas l’émulateur : elle lève un drapeau, ta boucle while 
//     (true) s’arrête, fetch rend la main, et le defer de main s’exécute.
// Ctrl-C. Le signal tue le processus sans defer. Le plus simple dans ton design
//  : désactiver ISIG, et traiter l’octet 3 dans serve_the_world comme une touche 
//  d’arrêt de l’émulateur, qui lève le même drapeau. Tu évites ainsi d’écrire un gestionnaire de signal.
// Les paniques. Un dépassement d’indice ou un @panic ne restaure rien non plus.
//  Là, stty sane reste ta roue de secours.

// Deux remarques moins urgentes :

// stdin redirigé. try stdin.enableRawMode() échoue si stdin est un tube, donc 
// l’émulateur refuse de démarrer. Tu en auras besoin pour le test abcq de l’étape 7 
// : en cas d’échec, continue sans mode brut et ne restaure rien à la sortie.
// Le moment de l’activation. Tu passes en mode brut avant de charger l’ELF. 
// Fais-le juste avant fetch, pour que les erreurs de chargement s’affichent dans un terminal normal.