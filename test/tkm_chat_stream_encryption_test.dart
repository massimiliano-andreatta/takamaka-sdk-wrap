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
      final plaintext =
          Uint8List.fromList(utf8.encode('attachment payload async'));

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

    // DR-030: identity is over ciphertext bytes, never over base64 wire text.
    test('encrypted_content_hash is SHA3-256 of ciphertext bytes (DR-030)', () {
      const password = 'symmetric-key-test';
      const scope = 'conversation-hash-test';
      final plaintext = Uint8List.fromList(utf8.encode('dr030 payload'));

      final encrypted = TkmChatStreamEncryption.encrypt(
        password: password,
        scope: scope,
        plaintext: plaintext,
      );

      final wireText = utf8.decode(encrypted.encryptedData);
      final ciphertext = Uint8List.fromList(
          base64.decode(wireText.replaceAll(RegExp(r'\s'), '')));
      final hashOfCiphertext =
          TkmChatStreamEncryption.computeHashHex(ciphertext);
      final hashOfBase64Text =
          TkmChatStreamEncryption.computeHashHex(encrypted.encryptedData);

      expect(encrypted.descriptor.encryptedContentHash, hashOfCiphertext);
      expect(
        encrypted.descriptor.encryptedContentHash,
        isNot(hashOfBase64Text),
      );
      // size / wire length stay encoded-form (DR-030 amendment).
      expect(encrypted.encryptedData.length, wireText.length);
    });

    test('decrypt rejects pre-DR-030 hash over base64 wire text', () {
      const password = 'symmetric-key-test';
      const scope = 'conversation-hash-test';
      final plaintext = Uint8List.fromList(utf8.encode('stale hash'));

      final encrypted = TkmChatStreamEncryption.encrypt(
        password: password,
        scope: scope,
        plaintext: plaintext,
      );

      final staleDescriptor = StreamEncryptedDescriptor.standard(
        salt: encrypted.descriptor.salt,
        iv: encrypted.descriptor.iv,
        encryptedContentHash:
            TkmChatStreamEncryption.computeHashHex(encrypted.encryptedData),
      );

      expect(
        () => TkmChatStreamEncryption.decrypt(
          password: password,
          descriptor: staleDescriptor,
          encryptedData: encrypted.encryptedData,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('PRE-DR-030'),
          ),
        ),
      );
    });

    test('decrypt accepts Java-style CRLF-wrapped base64 wire body', () {
      const password = 'symmetric-key-test';
      const scope = 'conversation-hash-test';
      final plaintext = Uint8List.fromList(
        List.generate(200, (i) => i % 256),
      );

      final encrypted = TkmChatStreamEncryption.encrypt(
        password: password,
        scope: scope,
        plaintext: plaintext,
      );

      final unwrapped = utf8.decode(encrypted.encryptedData);
      final wrapped = StringBuffer();
      for (var i = 0; i < unwrapped.length; i += 76) {
        final end = (i + 76 < unwrapped.length) ? i + 76 : unwrapped.length;
        wrapped.write(unwrapped.substring(i, end));
        if (end < unwrapped.length) wrapped.write('\r\n');
      }
      final wrappedBytes = Uint8List.fromList(utf8.encode(wrapped.toString()));

      final decrypted = TkmChatStreamEncryption.decrypt(
        password: password,
        descriptor: encrypted.descriptor,
        encryptedData: wrappedBytes,
        expectedPlaintextHashHex: encrypted.plaintextHashHex,
      );
      expect(decrypted, plaintext);
    });
  });
}
