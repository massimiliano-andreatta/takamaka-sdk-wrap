@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_chat_enums_api.dart';

import '../helpers/chat_api_guide_fixtures.dart';
import '../helpers/rschat_e2e_flow.dart';
import '../helpers/rschat_message_decrypt_helper.dart';

/// Live send to a specific partner signing public key on rschat TEST.
///
/// ```bash
/// cd takamaka-sdk-wrap && flutter test test/integration/rschat_send_to_partner_test.dart --run-skipped
/// ```
///
/// Env:
/// - `RSCHAT_PARTNER_SIGN_KEY` — recipient Ed25519 pubkey (url64), required
/// - `RSCHAT_E2E_MNEMONIC` — sender wallet mnemonic (25 words)
/// - `RSCHAT_E2E_SIGN_KEY_INDEX` — sender key index (default 4)
void main() {
  final partnerKey = Platform.environment['RSCHAT_PARTNER_SIGN_KEY']?.trim() ??
      'WqvVSMgbEiuARIC-EGzgWNEIP8dU0g3o4R0vnBE-RfM.';

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

  group(
    'rschat send to partner — ${TkmChatEnumEnvironments.test.wsUrl}',
    () {
      late RschatE2eFlow senderFlow;
      late RschatMessageDecryptHelper senderDecrypt;

      setUpAll(() async {
        senderFlow = RschatE2eFlow();
        await senderFlow.registerSession(
          mnemonic: mnemonic(),
          signKeyIndex: signKeyIndex,
        );
        senderDecrypt = RschatMessageDecryptHelper(
          api: senderFlow.api,
          keys: senderFlow.keys!,
        );
      });

      tearDownAll(() async {
        await senderFlow.disconnect();
      });

      test(
        'requestkeys → chat → send → decrypt history for $partnerKey',
        () async {
          final myPk = await senderFlow.mySignPublicKey();
          print('Sender sign pubkey: $myPk');
          print('Partner sign pubkey: $partnerKey');
          print('Server: ${TkmChatEnumEnvironments.test.wsUrl}');

          // Probe partner registration on server.
          var partnerFound = false;
          try {
            await for (final user in senderFlow.api.requestKeys(
              keys: senderFlow.keys!,
              otherPublicKeys: [partnerKey],
            )) {
              partnerFound = true;
              print('Partner on server: from=${user['from']}');
            }
          } catch (e) {
            fail('requestkeys failed for partner $partnerKey: $e');
          }
          expect(partnerFound, isTrue, reason: 'Partner not registered on rschat');

          final chat = await senderFlow.findOrCreateDirectChat(
            title: 'Partner test ${DateTime.now().millisecondsSinceEpoch}',
            partnerSignPublicKey: partnerKey,
          );
          print('Conversation hash: ${chat.conversationHash}');

          final keyResult = await senderDecrypt.resolveSymmetricKey(
            chat.conversationHash,
          );
          expect(
            keyResult.symmetricKey,
            isNotNull,
            reason: keyResult.error ?? 'symmetric key missing',
          );

          final messageText =
              'Takamaka partner ping ${DateTime.now().toIso8601String()}';
          final sendResponse = await senderFlow.sendTextMessage(
            conversationHash: chat.conversationHash,
            symmetricKey: chat.symmetricKey,
            text: messageText,
          );
          print('Send response keys: ${sendResponse.keys.toList()}');

          await Future<void>.delayed(const Duration(seconds: 2));

          final history = await senderDecrypt.decryptHistory(
            conversationHash: chat.conversationHash,
            symmetricKey: keyResult.symmetricKey!,
            limit: 30,
          );

          print(
            'History: events=${history.totalEvents} decrypted=${history.decryptedCount}',
          );
          for (final sample in history.sampleTexts) {
            print('  sample: $sample');
          }
          for (final failure in history.failures.take(5)) {
            print('  failure: $failure');
          }

          expect(history.decryptedCount, greaterThan(0));
          expect(
            history.sampleTexts.any((t) => t.contains('Takamaka partner ping')),
            isTrue,
            reason: 'Sent text not found in decrypted history',
          );
        },
        timeout: const Timeout(Duration(minutes: 3)),
      );
    },
  );
}
