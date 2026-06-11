import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/models/tkm_wallet_persistence.dart';

void main() {
  final legacyWallet = <String, dynamic>{
    'isDefault': true,
    'walletName': 'MyWallet',
    'seed': 'test-seed',
    'addresses': [
      <String, dynamic>{
        'index': 0,
        'name': 'Address Main',
        'walletName': 'MyWallet',
        'seed': 'test-seed',
        'favorite': false,
        'visible': true,
      },
      <String, dynamic>{
        'index': 1,
        'name': 'Savings',
        'walletName': 'MyWallet',
        'seed': 'test-seed',
        'favorite': false,
        'visible': true,
      },
    ],
  };

  final candidateWithExplicitBoth = <String, dynamic>{
    'isDefault': true,
    'walletName': 'MyWallet',
    'seed': 'test-seed',
    'addresses': [
      <String, dynamic>{
        'index': 0,
        'name': 'Address Main',
        'walletName': 'MyWallet',
        'seed': 'test-seed',
        'favorite': false,
        'visible': true,
        'usage': 'both',
      },
      <String, dynamic>{
        'index': 1,
        'name': 'Savings',
        'walletName': 'MyWallet',
        'seed': 'test-seed',
        'favorite': false,
        'visible': true,
      },
    ],
  };

  test('legacy json without usage equals canonical both', () {
    expect(
      TkmWalletPersistence.mapsEqualForStorage(
        legacyWallet,
        candidateWithExplicitBoth,
      ),
      isTrue,
    );
  });

  test('usage change is detected', () {
    final addresses = List<Map<String, dynamic>>.from(
      legacyWallet['addresses'] as List,
    );
    final chatOnly = <String, dynamic>{
      ...legacyWallet,
      'addresses': [
        addresses[0],
        <String, dynamic>{...addresses[1], 'usage': 'chat_only'},
      ],
    };
    expect(
      TkmWalletPersistence.mapsEqualForStorage(legacyWallet, chatOnly),
      isFalse,
    );
  });

  test('visible int legacy form normalizes equal to bool', () {
    final addresses = List<Map<String, dynamic>>.from(
      legacyWallet['addresses'] as List,
    );
    final withIntVisible = <String, dynamic>{
      ...legacyWallet,
      'addresses': [
        addresses[0],
        <String, dynamic>{...addresses[1], 'visible': 1},
      ],
    };
    expect(
      TkmWalletPersistence.mapsEqualForStorage(legacyWallet, withIntVisible),
      isTrue,
    );
  });
}
