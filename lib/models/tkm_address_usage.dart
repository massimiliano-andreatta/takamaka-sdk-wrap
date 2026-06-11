/// How a derived address may be used inside the app.
///
/// Stored JSON key: `usage` (`both` | `chat_only` | `blockchain_only`).
/// **Backward compatible:** wallets saved before this field was introduced behave
/// as [both] when `usage` is absent (same as only using `visible` before).
enum TkmAddressUsage {
  /// Encrypted chat (rschat) only; excluded from wallet carousel / on-chain ops.
  chatOnly,

  /// Blockchain operations only; excluded from chat identity picker.
  blockchainOnly,

  /// Both chat and blockchain (default for existing wallets).
  both;

  bool get enabledForChat =>
      this == TkmAddressUsage.chatOnly || this == TkmAddressUsage.both;

  bool get enabledForBlockchain =>
      this == TkmAddressUsage.blockchainOnly || this == TkmAddressUsage.both;

  String toJson() {
    switch (this) {
      case TkmAddressUsage.chatOnly:
        return 'chat_only';
      case TkmAddressUsage.blockchainOnly:
        return 'blockchain_only';
      case TkmAddressUsage.both:
        return 'both';
    }
  }
}
