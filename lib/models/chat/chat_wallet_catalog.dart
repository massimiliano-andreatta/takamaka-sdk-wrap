import 'package:takamaka_sdk_wrap/models/tkm_address_usage.dart';

/// Lightweight wallet/address rows for UI pickers (no key derivation).
class ChatWalletCatalogEntry {
  ChatWalletCatalogEntry({
    required this.walletName,
    required this.isDefault,
    required this.addresses,
  });

  final String walletName;
  final bool isDefault;
  final List<ChatAddressCatalogEntry> addresses;

  List<ChatAddressCatalogEntry> get visibleAddresses =>
      addresses.where((a) => a.visible).toList();

  List<ChatAddressCatalogEntry> get chatEligibleAddresses =>
      addresses.where((a) => a.eligibleForChat).toList();
}

class ChatAddressCatalogEntry {
  ChatAddressCatalogEntry({
    required this.index,
    required this.name,
    required this.visible,
    required this.usage,
  });

  final int index;
  final String name;
  final bool visible;
  final TkmAddressUsage usage;

  bool get eligibleForChat => visible && usage.enabledForChat;
}
