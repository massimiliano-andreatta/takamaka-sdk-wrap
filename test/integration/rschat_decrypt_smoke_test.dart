@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_encryption.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_rsa.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_chat_enums_api.dart';

import '../helpers/chat_api_guide_fixtures.dart';
import '../helpers/rschat_e2e_flow.dart';
import '../helpers/rschat_message_decrypt_helper.dart';

/// Smoke: retrieve conversation key + decrypt message history on live rschat.
///
/// Run:
/// `cd takamaka-sdk-wrap && flutter test test/integration/rschat_decrypt_smoke_test.dart --run-skipped`
///
/// Optional env: `RSCHAT_E2E_MNEMONIC`, `RSCHAT_E2E_SIGN_KEY_INDEX` (default 4).
void main() {
  group('rschat RSA crypto (local, no network)', () {
    test('RSA OAEP-SHA256 invite round-trip + persistence', () async {
      final pair = await TkmChatRsaKeyPair.generate();
      final symKey = TkmChatEncryption.generateSymmetricKey();
      final enc = TkmChatRsaKeyPair.encryptWithPublicKey(pair.publicKey, symKey);
      expect(pair.decrypt(enc), symKey);

      final restored = TkmChatRsaKeyPair.fromStorageJson(pair.toStorageJson());
      expect(restored, isNotNull);
      expect(restored!.decrypt(enc), symKey);
    });
  });

  final signKeyIndex = int.tryParse(
        Platform.environment['RSCHAT_E2E_SIGN_KEY_INDEX'] ?? '4',
      ) ??
      ChatApiGuideFixtures.guideSignKeyIndex;

  List<String> mnemonic() {
    final fromEnv = Platform.environment['RSCHAT_E2E_MNEMONIC'];
    if (fromEnv != null && fromEnv.trim().isNotEmpty) {
      return fromEnv.trim().split(RegExp(r'\s+'));
    }
    return ChatApiGuideFixtures.guideMnemonic;
  }

  group('rschat decrypt smoke — ${TkmChatEnumEnvironments.test.wsUrl}', () {
    late RschatE2eFlow flow;
    late RschatMessageDecryptHelper decryptHelper;

    setUpAll(() async {
      flow = RschatE2eFlow();
      await flow.registerSession(
        mnemonic: mnemonic(),
        signKeyIndex: signKeyIndex,
      );
      decryptHelper = RschatMessageDecryptHelper(
        api: flow.api,
        keys: flow.keys!,
      );
    });

    tearDownAll(() async {
      await flow.disconnect();
    });

    /// Single live flow: one connection, one createconversation (rate-limit friendly).
    test(
      'create chat, resolve sym key, send message, decrypt history',
      () async {
        const partnerSignKey = 'M7KYwZHk4eoqvs23GQ-ITkB_wBbT8gqSvYhEx59ll0o.';
        final chat = await flow.findOrCreateDirectChat(
          title: 'Decrypt smoke ${DateTime.now().millisecondsSinceEpoch}',
          partnerSignPublicKey: partnerSignKey,
        );

        final keyResult =
            await decryptHelper.resolveSymmetricKey(chat.conversationHash);
        expect(
          keyResult.symmetricKey,
          isNotNull,
          reason: keyResult.error ?? 'symmetric key missing',
        );
        expect(keyResult.symmetricKey!.length, 400);

        final messageText =
            'Decrypt smoke ping ${DateTime.now().millisecondsSinceEpoch}';
        await flow.sendTextMessage(
          conversationHash: chat.conversationHash,
          symmetricKey: chat.symmetricKey,
          text: messageText,
        );

        await Future<void>.delayed(const Duration(seconds: 2));

        final history = await decryptHelper.decryptHistory(
          conversationHash: chat.conversationHash,
          symmetricKey: keyResult.symmetricKey!,
          limit: 20,
        );

        expect(history.totalEvents, greaterThan(0));
        expect(history.decryptedCount, greaterThan(0));
        expect(
          history.sampleTexts.any((t) => t.contains('Decrypt smoke ping')),
          isTrue,
          reason: 'failures: ${history.failures.take(3).join("; ")}',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
