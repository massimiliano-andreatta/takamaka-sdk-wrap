@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_chat_enums_api.dart';

import '../helpers/chat_api_guide_fixtures.dart';
import '../helpers/rschat_e2e_flow.dart';
import '../helpers/rschat_message_decrypt_helper.dart';

/// Decrypt history for an existing conversation (after rschat_send_to_partner_test).
///
/// ```bash
/// cd takamaka-sdk-wrap && \
/// RSCHAT_CONVERSATION_HASH=<hash> \
/// flutter test test/integration/rschat_decrypt_conversation_test.dart --run-skipped
/// ```
void main() {
  final conversationHash =
      Platform.environment['RSCHAT_CONVERSATION_HASH']?.trim() ??
          '2f926fc885f73efe1d8788c3f72bc1b72dcae05c6c5f707955a09ec01dacdb91';

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

  group('rschat decrypt conversation — ${TkmChatEnumEnvironments.test.wsUrl}', () {
    test(
      'resolve sym key + decrypt history for $conversationHash',
      () async {
        final flow = RschatE2eFlow();
        await flow.registerSession(
          mnemonic: mnemonic(),
          signKeyIndex: signKeyIndex,
        );
        addTearDown(flow.disconnect);

        final helper = RschatMessageDecryptHelper(
          api: flow.api,
          keys: flow.keys!,
        );

        final myPk = await flow.mySignPublicKey();
        print('Sender: $myPk');
        print('Conversation: $conversationHash');

        ({String? symmetricKey, String? error, List<String> detailKeys})? keyResult;
        for (var attempt = 0; attempt < 4; attempt++) {
          if (attempt > 0) {
            await Future<void>.delayed(Duration(seconds: 3 * attempt));
          }
          keyResult = await helper.resolveSymmetricKey(conversationHash);
          if (keyResult.symmetricKey != null) break;
          print('sym key attempt $attempt: ${keyResult.error}');
        }
        expect(keyResult!.symmetricKey, isNotNull, reason: keyResult.error);

        ({
          int totalEvents,
          int decryptedCount,
          List<String> sampleTexts,
          List<String> failures,
        })? history;
        for (var attempt = 0; attempt < 4; attempt++) {
          if (attempt > 0) {
            await Future<void>.delayed(Duration(seconds: 4 * attempt));
          }
          try {
            history = await helper.decryptHistory(
              conversationHash: conversationHash,
              symmetricKey: keyResult.symmetricKey!,
              limit: 30,
            );
            break;
          } catch (e) {
            print('history attempt $attempt failed: $e');
            if (attempt == 3) rethrow;
          }
        }

        print(
          'History events=${history!.totalEvents} decrypted=${history.decryptedCount}',
        );
        for (final t in history.sampleTexts) {
          print('  text: $t');
        }
        for (final f in history.failures.take(5)) {
          print('  fail: $f');
        }

        expect(history.decryptedCount, greaterThan(0));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
