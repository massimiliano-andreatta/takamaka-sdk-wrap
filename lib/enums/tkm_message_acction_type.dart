enum TkmMessageActionType {
  requestPay("rp"),
  stake("st"),
  stakeUndo("su"),
  blob("b"),
  exportWalletEncrypted("we");

  final String shortCode;
  const TkmMessageActionType(this.shortCode);

  // Metodo per ottenere l'ActionType da un codice
  static TkmMessageActionType fromShortCode(String code) {
    return TkmMessageActionType.values.firstWhere(
          (e) => e.shortCode == code,
      orElse: () => throw ArgumentError("Codice non valido: $code"),
    );
  }
}
