import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_encryption.dart';

/// Password-based AES (v0_1_a) per SERVER_API_GUIDE — client-side message/topic crypto.
void main() {
  group('TkmChatEncryption', () {
    test('hash256B64Url is stable for same input', () {
      final a = TkmChatEncryption.hash256B64Url('topic-title');
      final b = TkmChatEncryption.hash256B64Url('topic-title');
      expect(a, b);
      expect(a, isNotEmpty);
    });

    test('generateSymmetricKey has expected length', () {
      final key = TkmChatEncryption.generateSymmetricKey();
      expect(key.length, 400);
    });

    test('TOPIC_MESSAGE encrypt/decrypt round-trip', () {
      const password = 'test-symmetric-key-for-message-scope-0123456789';
      const plaintext = {
        'text_message': 'Ciphertext test',
        'attached_media': <Map<String, dynamic>>[],
      };

      final encrypted =
          TkmChatEncryption.encryptMessageContent(plaintext, password);
      expect(encrypted['tk_version'], 'v0_1_a');
      expect(encrypted['scope'], 'TOPIC_MESSAGE');
      expect(encrypted['transformation'], 'AES/CBC/PKCS5Padding');
      expect(encrypted['encrypted_message'], isA<List>());
      expect(encrypted['encrypted_message'], hasLength(2));
      final wire = TkmChatEncryption.toWireEncMessage(encrypted);
      expect(wire['tv'], 'v0_1_a');
      expect(wire['tr'], 'AES/CBC/PKCS5Padding');
      expect(wire['em'], isA<List>());
      expect(wire['em'], hasLength(2));
      expect(wire.containsKey('salt'), isFalse);
      expect(wire['pa'], 'PBKDF2WithHmacSHA512');

      final decrypted = TkmChatEncryption.decryptMessageContent(
        TkmChatEncryption.toWireEncMessage(encrypted),
        password,
      );
      expect(decrypted['text_message'], plaintext['text_message']);
      expect(decrypted['attached_media'], isEmpty);
    });

    test('TOPIC_CREATION encrypt/decrypt round-trip', () {
      const password = 'topic-symmetric-key-password-abcdefghijklmnop';
      final topicTitleKey = {
        'topic_title': 'My group',
        'symmetric_key': password,
      };

      final encrypted =
          TkmChatEncryption.encryptTopicTitle(topicTitleKey, password);
      expect(encrypted['scope'], 'TOPIC_CREATION');

      final jsonString = TkmChatEncryption.decryptWithPassword(
        password: password,
        encMessage: TkmChatEncryption.toWireEncMessage(encrypted),
        scope: 'TOPIC_CREATION',
      );
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['topic_title'], 'My group');
      expect(decoded['symmetric_key'], password);
    });

    test('scope mismatch throws', () {
      const password = 'wrong-scope-key-0123456789012345678901234567890';
      final encrypted = TkmChatEncryption.encryptMessageContent(
        {'text_message': 'x', 'attached_media': <Map<String, dynamic>>[]},
        password,
      );
      expect(
        () => TkmChatEncryption.decryptWithPassword(
          password: password,
          encMessage: encrypted,
          scope: 'TOPIC_CREATION',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
