import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_rsa.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_base64_url.dart';

void main() {
  test('TkmChatRsaKeyPair.generate produces RSA-4096 key pair', () async {
    final pair = await TkmChatRsaKeyPair.generate();
    expect(pair.publicKeyUrl64, isNotEmpty);
    expect(pair.publicKey.modulus!.bitLength, greaterThanOrEqualTo(4090));
    expect(pair.publicKey.exponent, BigInt.from(65537));
  });

  test('encrypt/decrypt round-trip uses OAEP-SHA256', () async {
    final pair = await TkmChatRsaKeyPair.generate();
    const plaintext = 'topic-symmetric-key-abc123';
    final ciphertext = pair.encrypt(plaintext);
    expect(pair.decrypt(ciphertext), plaintext);
  });

  test('decrypt supports OAEP-SHA1 legacy invites', () async {
    final pair = await TkmChatRsaKeyPair.generate();
    const plaintext = 'legacy-invite-key';
    final engine = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(pair.publicKey));
    final ciphertext = TkmBase64Url.encode(
      engine.process(Uint8List.fromList(utf8.encode(plaintext))),
    );
    expect(pair.decrypt(ciphertext), plaintext);
  });

  test('storage json round-trip preserves key material', () async {
    final pair = await TkmChatRsaKeyPair.generate();
    const plaintext = 'persisted-rsa-test';
    final restored = TkmChatRsaKeyPair.fromStorageJson(pair.toStorageJson());
    expect(restored, isNotNull);
    final ciphertext = restored!.encrypt(plaintext);
    expect(restored.decrypt(ciphertext), plaintext);
  });

  test('fromWalletSeed is deterministic for same wallet identity', () async {
    const seed = 'wallet-seed-deterministic-test-value';
    final first = await TkmChatRsaKeyPair.fromWalletSeed(
      seed,
      signKeyIndex: 0,
    );
    final second = await TkmChatRsaKeyPair.fromWalletSeed(
      seed,
      signKeyIndex: 0,
    );
    expect(first.publicKeyUrl64, second.publicKeyUrl64);

    const plaintext = 'derived-rsa-invite-key';
    final ciphertext = first.encrypt(plaintext);
    expect(second.decrypt(ciphertext), plaintext);
  });
}
