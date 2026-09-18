import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/models/tkm_address_usage.dart';
import 'package:takamaka_sdk_wrap/models/tkm_wallet_legacy_parse.dart';

void main() {
  test('parseUsage defaults to both', () {
    expect(TkmWalletLegacyParse.parseUsage(null), TkmAddressUsage.both);
    expect(TkmWalletLegacyParse.parseUsage('unknown'), TkmAddressUsage.both);
  });

  test('round-trip json', () {
    for (final usage in TkmAddressUsage.values) {
      expect(TkmWalletLegacyParse.parseUsage(usage.toJson()), usage);
    }
  });

  test('enabled flags', () {
    expect(TkmAddressUsage.chatOnly.enabledForChat, isTrue);
    expect(TkmAddressUsage.chatOnly.enabledForBlockchain, isFalse);
    expect(TkmAddressUsage.blockchainOnly.enabledForChat, isFalse);
    expect(TkmAddressUsage.blockchainOnly.enabledForBlockchain, isTrue);
    expect(TkmAddressUsage.both.enabledForChat, isTrue);
    expect(TkmAddressUsage.both.enabledForBlockchain, isTrue);
  });
}
