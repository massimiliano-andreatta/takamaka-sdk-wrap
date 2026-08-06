import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_stream_encryption.dart';
import 'package:takamaka_sdk_wrap/models/chat/stream_encrypted_descriptor.dart';

void main() {
  group('TkmChatStreamEncryption', () {
    test('encrypt/decrypt round-trip', () {
      const password = 'symmetric-key-test';
      const scope = 'conversation-hash-test';
      final plaintext = Uint8List.fromList(utf8.encode('attachment payload'));

      final encrypted = TkmChatStreamEncryption.encrypt(
        password: password,
        scope: scope,
        plaintext: plaintext,
      );

      final decrypted = TkmChatStreamEncryption.decrypt(
        password: password,
        descriptor: encrypted.descriptor,
        encryptedData: encrypted.encryptedData,
        expectedPlaintextHashHex: encrypted.plaintextHashHex,
      );

      expect(decrypted, plaintext);
    });

    test('encryptAsync/decrypt round-trip', () async {
      const password = 'symmetric-key-test';
      const scope = 'conversation-hash-test';
      final plaintext = Uint8List.fromList(utf8.encode('attachment payload async'));

      final encrypted = await TkmChatStreamEncryption.encryptAsync(
        password: password,
        scope: scope,
        plaintext: plaintext,
      );

      final decrypted = TkmChatStreamEncryption.decrypt(
        password: password,
        descriptor: encrypted.descriptor,
        encryptedData: encrypted.encryptedData,
        expectedPlaintextHashHex: encrypted.plaintextHashHex,
      );

      expect(decrypted, plaintext);
    });

    test('descriptor round-trip json', () {
      final descriptor = StreamEncryptedDescriptor.standard(
        salt: 'aa' * 64,
        iv: 'bb' * 24,
        encryptedContentHash: 'cc' * 64,
      );
      final restored = StreamEncryptedDescriptor.fromJson(descriptor.toJson());
      expect(restored.salt, descriptor.salt);
      expect(restored.iv, descriptor.iv);
      expect(restored.encryptedContentHash, descriptor.encryptedContentHash);
    });
  });
}
