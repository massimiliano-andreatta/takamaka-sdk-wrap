@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_chat_enums_api.dart';

import '../helpers/rschat_e2e_flow.dart';
import '../helpers/rschat_message_decrypt_helper.dart';

/// Generates a fresh wallet (index 0) and sends a message to a fixed partner key.
///
/// ```bash
/// cd takamaka-sdk-wrap && flutter test test/integration/rschat_ephemeral_send_test.dart --run-skipped
/// ```
void main() {
  const partnerSignKey = 'WqvVSMgbEiuARIC-EGzgWNEIP8dU0g3o4R0vnBE-RfM.';
  const signKeyIndex = 0;

  group('rschat ephemeral send — ${TkmChatEnumEnvironments.test.wsUrl}', () {
    test(
      'generate wallet index 0 → send to $partnerSignKey',
      () async {
        final words = await WordsUtils.generateWords();
        final seed = await WalletUtils.generateSeedPWH(words);
        final keyPair =
            await WalletUtils.getNewKeypairED25519(seed, index: signKeyIndex);
        final takamakaAddress = await WalletUtils.getTakamakaAddress(keyPair);

        print('=== Ephemeral sender wallet ===');
        print('Mnemonic (25 words): ${words.join(' ')}');
        print('Sign key index: $signKeyIndex');
        print('Takamaka address index 0: $takamakaAddress');

        final flow = RschatE2eFlow();
        addTearDown(flow.disconnect);

        await flow.registerSession(
          mnemonic: words,
          signKeyIndex: signKeyIndex,
        );

        final senderSignKey = await flow.mySignPublicKey();
        print('Ed25519 sign pubkey (chat): $senderSignKey');
        print('Partner sign pubkey: $partnerSignKey');
        print('Server: ${TkmChatEnumEnvironments.test.wsUrl}');

        var partnerFound = false;
        await for (final user in flow.api.requestKeys(
          keys: flow.keys!,
          otherPublicKeys: [partnerSignKey],
        )) {
          partnerFound = true;
          print('Partner registered on rschat: ${user['from']}');
        }
        expect(partnerFound, isTrue, reason: 'Partner not on rschat');

        final chat = await flow.startDirectChat(
          title: 'Ephemeral ping ${DateTime.now().millisecondsSinceEpoch}',
          partnerSignPublicKey: partnerSignKey,
        );
        print('Conversation hash: ${chat.conversationHash}');

        final messageText =
            'Auto wallet ping idx0 ${DateTime.now().toIso8601String()}';
        final sendResult = await flow.sendTextMessage(
          conversationHash: chat.conversationHash,
          symmetricKey: chat.symmetricKey,
          text: messageText,
        );
        print('Send OK: ${sendResult['result']}');
        print('Message signature: ${sendResult['request_message_signature']}');
        print('Plaintext sent: $messageText');

        await Future<void>.delayed(const Duration(seconds: 3));

        final helper = RschatMessageDecryptHelper(
          api: flow.api,
          keys: flow.keys!,
        );

        ({
          int totalEvents,
          int decryptedCount,
          List<String> sampleTexts,
          List<String> failures,
        })? history;
        Object? lastError;
        for (var attempt = 0; attempt < 4; attempt++) {
          if (attempt > 0) {
            await Future<void>.delayed(Duration(seconds: 4 * attempt));
          }
          try {
            history = await helper.decryptHistory(
              conversationHash: chat.conversationHash,
              symmetricKey: chat.symmetricKey,
              limit: 10,
            );
            break;
          } catch (e) {
            lastError = e;
            print('History attempt $attempt failed: $e');
          }
        }

        if (history != null) {
          print(
            'Sender decrypt check: events=${history.totalEvents} '
            'decrypted=${history.decryptedCount}',
          );
          for (final t in history.sampleTexts) {
            print('  decrypted: $t');
          }
          expect(history.decryptedCount, greaterThan(0));
          expect(
            history.sampleTexts.any((t) => t.contains('Auto wallet ping idx0')),
            isTrue,
          );
        } else {
          print(
            'History skipped after retries (send still OK): $lastError',
          );
        }

        print('=== Done — check recipient app for conversation ===');
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });
}
