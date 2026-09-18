import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/models/tkm_address_usage.dart';
import 'package:takamaka_sdk_wrap/models/tkm_wallet_legacy_parse.dart';

void main() {
  group('parseUsage', () {
    test('null and missing mean both', () {
      expect(TkmWalletLegacyParse.parseUsage(null), TkmAddressUsage.both);
      expect(TkmWalletLegacyParse.parseUsage(''), TkmAddressUsage.both);
      expect(TkmWalletLegacyParse.parseUsage('legacy_value'), TkmAddressUsage.both);
    });

    test('accepts known strings', () {
      expect(
        TkmWalletLegacyParse.parseUsage('chat_only'),
        TkmAddressUsage.chatOnly,
      );
      expect(
        TkmWalletLegacyParse.parseUsage('blockchain_only'),
        TkmAddressUsage.blockchainOnly,
      );
    });

    test('ignores non-string stored values', () {
      expect(TkmWalletLegacyParse.parseUsage(1), TkmAddressUsage.both);
      expect(TkmWalletLegacyParse.parseUsage(true), TkmAddressUsage.both);
    });
  });

  group('parseVisible', () {
    test('index 0 always visible', () {
      expect(
        TkmWalletLegacyParse.parseVisible(false, index: 0),
        isTrue,
      );
    });

    test('defaults to visible when absent', () {
      expect(TkmWalletLegacyParse.parseVisible(null, index: 1), isTrue);
    });

    test('parses int and string legacy forms', () {
      expect(TkmWalletLegacyParse.parseVisible(0, index: 1), isFalse);
      expect(TkmWalletLegacyParse.parseVisible(1, index: 1), isTrue);
      expect(TkmWalletLegacyParse.parseVisible('false', index: 2), isFalse);
    });
  });

  group('legacy wallet address json without usage', () {
    test('eligible flags match pre-upgrade visible-only behaviour', () {
      final usage = TkmWalletLegacyParse.parseUsage(null);
      expect(usage, TkmAddressUsage.both);
      expect(usage.enabledForChat, isTrue);
      expect(usage.enabledForBlockchain, isTrue);

      final visible = TkmWalletLegacyParse.parseVisible(true, index: 1);
      expect(visible && usage.enabledForChat, isTrue);
      expect(visible && usage.enabledForBlockchain, isTrue);

      final hidden = TkmWalletLegacyParse.parseVisible(false, index: 1);
      expect(hidden && usage.enabledForChat, isFalse);
    });
  });
}
