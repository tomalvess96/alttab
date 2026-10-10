/// Decide se o tap de teclado precisa ser recriado.
/// `tapIsEnabled` não basta: já houve tap "ligado" que levava segundos por tecla e nunca
/// chamava o callback — o Option+Tab sumia sem nenhum aviso de `tapDisabledByTimeout`.
public enum TapHealth {
    /// Acima disto o sistema já desiste da tecla e a entrega direto ao app da frente.
    public static let maxLatencyMicros: Float = 1_000_000

    public static func needsRestart(found: Bool, enabled: Bool, avgLatencyMicros: Float) -> Bool {
        !found || !enabled || avgLatencyMicros >= maxLatencyMicros
    }
}
