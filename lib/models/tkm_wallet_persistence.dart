import 'dart:convert';

import 'package:takamaka_sdk_wrap/models/tkm_address_usage.dart';
import 'package:takamaka_sdk_wrap/models/tkm_wallet_legacy_parse.dart';

/// Canonical comparison for wallet JSON in SharedPreferences (backward compatible).
class TkmWalletPersistence {
  TkmWalletPersistence._();

  /// True when [stored] and [candidate] represent the same wallet state for persistence.
  ///
  /// Ignores formatting and treats missing `usage` as [TkmAddressUsage.both].
  static bool mapsEqualForStorage(
    Map<String, dynamic> stored,
    Map<String, dynamic> candidate,
  ) {
    return jsonEncode(normalizeWalletMap(stored)) ==
        jsonEncode(normalizeWalletMap(candidate));
  }

  /// Stable map used only for equality checks (not for writing legacy files).
  static Map<String, dynamic> normalizeWalletMap(Map<String, dynamic> map) {
    final rawAddresses = map['addresses'] as List<dynamic>? ?? [];
    final normalizedAddresses = <Map<String, dynamic>>[];

    for (final raw in rawAddresses) {
      if (raw is! Map) continue;
      final addressMap = Map<String, dynamic>.from(raw);
      final index = (addressMap['index'] as num?)?.toInt() ?? 0;
      final usage = TkmWalletLegacyParse.parseUsage(addressMap['usage']);
      final visible = TkmWalletLegacyParse.parseVisible(
        addressMap['visible'],
        index: index,
      );

      final normalized = <String, dynamic>{
        'index': index,
        'name': addressMap['name'] ?? '',
        'walletName': addressMap['walletName'] ?? map['walletName'],
        'favorite': addressMap['favorite'] == true,
        'visible': visible,
        'seed': addressMap['seed'],
      };
      if (usage != TkmAddressUsage.both) {
        normalized['usage'] = usage.toJson();
      }
      normalizedAddresses.add(normalized);
    }

    normalizedAddresses.sort(
      (a, b) => (a['index'] as int).compareTo(b['index'] as int),
    );

    return {
      'isDefault': map['isDefault'] == true,
      'walletName': map['walletName'],
      'seed': map['seed'],
      'addresses': normalizedAddresses,
    };
  }
}
