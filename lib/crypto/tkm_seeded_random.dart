import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'package:takamaka_sdk_wrap/crypto/tkm_pbkdf2.dart';

/// Deterministic PRNG matching wallet-core `SeededRandom` / Java RSA keygen.
class TkmSeededRandom implements SecureRandom {
  TkmSeededRandom({
    required this.walletSeed,
    required this.scope,
    required this.keyNumber,
  });

  final String walletSeed;
  final String scope;
  final int keyNumber;

  int _rsaIterationsInSameInstance = 0;

  @override
  String get algorithmName => 'TkmSeededRandom';

  @override
  BigInt nextBigInteger(int bitLength) {
    final bytes = nextBytes((bitLength + 7) ~/ 8);
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    if (bitLength % 8 != 0) {
      result = result >> (8 - (bitLength % 8));
    }
    return result;
  }

  @override
  Uint8List nextBytes(int count) {
    var password = walletSeed;
    if (_rsaIterationsInSameInstance > 0) {
      password = walletSeed + _rsaIterationsInSameInstance.toString();
    }
    final bytes = TkmPbkdf2.deriveKey(
      password: password,
      salt: scope,
      iterations: keyNumber,
      keyLengthBits: count * 8,
    );
    _rsaIterationsInSameInstance++;
    return bytes;
  }

  @override
  int nextUint16() {
    final bytes = nextBytes(2);
    return (bytes[0] << 8) | bytes[1];
  }

  @override
  int nextUint32() {
    final bytes = nextBytes(4);
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  @override
  int nextUint8() => nextBytes(1)[0];

  @override
  void seed(CipherParameters params) {}
}

/// Wallet key-chain scope used by Java `FixedParameters.WALLET_KEY_CHAIN`.
abstract final class TkmWalletKeyScopes {
  static const walletKeyChain = '__WKCH__';
}
