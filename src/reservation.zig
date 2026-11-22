// Réservation de LR/SC.
//
// lr.w pose une réservation sur une adresse ; sc.w n'écrit que si la
// réservation est encore valable pour CETTE adresse, et la consomme
// toujours (succès ou échec).
//
// Un hart n'a qu'UNE seule réservation à la fois : pas de pile. Un nouveau
// lr.w remplace l'ancienne réservation, et n'importe quel sc.w la détruit.
//
// Règle de sécurité : un sc qui échoue alors qu'il aurait pu réussir n'est
// pas grave (le logiciel boucle et réessaie). Un sc qui RÉUSSIT alors qu'il
// aurait dû échouer casse l'atomicité. Dans le doute : échec.

// ===========================================================================
// QUI doit appeler clear() en dehors de sc (rep dans : trap.zig).
// ===========================================================================

pub var addr_reserved: u32 = 0;

/// Appelée par lr.w, avec l'adresse lue (déjà vérifiée alignée et valide).
pub fn reserve(addr: u32) void {
    addr_reserved = addr;
}

/// Appelée par sc.w AVANT d'écrire. Renvoie true si sc a le droit d'écrire
/// à `addr`. Dans tous les cas, la réservation est consommée.
pub fn check_and_consume(addr: u32) bool {
    const res =  addr == addr_reserved;
    clear();
    return res;
}

/// Détruit la réservation, s'il y en a une.
pub fn clear() void {
    addr_reserved = 0;
}
