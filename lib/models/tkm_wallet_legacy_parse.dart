import 'package:takamaka_sdk_wrap/models/tkm_address_usage.dart';

/// Parsers for wallet JSON written by older app versions (no [usage] field, loose types).
class TkmWalletLegacyParse {
  TkmWalletLegacyParse._();

  /// Restores [TkmAddressUsage]; missing or unknown values mean **both** (pre-upgrade behaviour).
  static TkmAddressUsage parseUsage(dynamic value) {
    if (value == null) return TkmAddressUsage.both;
    if (value is! String) return TkmAddressUsage.both;
    switch (value.trim().toLowerCase()) {
      case 'chat_only':
      case 'chatonly':
        return TkmAddressUsage.chatOnly;
      case 'blockchain_only':
      case 'blockchainonly':
        return TkmAddressUsage.blockchainOnly;
      case 'both':
        return TkmAddressUsage.both;
      default:
        return TkmAddressUsage.both;
    }
  }

  /// Restores visibility; index 0 is always visible (legacy rule).
  static bool parseVisible(dynamic value, {required int index}) {
    if (index == 0) return true;
    if (value == null) return true;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'false' || lower == '0') return false;
      return true;
    }
    return true;
  }
}
