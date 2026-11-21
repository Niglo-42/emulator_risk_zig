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
// À ÉCRIRE PAR THOMAS : l'état (variables globales) et les 3 fonctions.
// Pense aussi à QUI doit appeler clear() en dehors de sc (indice : trap.zig).
// ===========================================================================

/// Appelée par lr.w, avec l'adresse lue (déjà vérifiée alignée et valide).
pub fn reserve(addr: u32) void {
    _ = addr;
    @panic("reservation.reserve n'est pas encore écrit");
}

/// Appelée par sc.w AVANT d'écrire. Renvoie true si sc a le droit d'écrire
/// à `addr`. Dans tous les cas, la réservation est consommée.
pub fn check_and_consume(addr: u32) bool {
    _ = addr;
    @panic("reservation.check_and_consume n'est pas encore écrit");
}

/// Détruit la réservation, s'il y en a une.
pub fn clear() void {
    @panic("reservation.clear n'est pas encore écrit");
}
