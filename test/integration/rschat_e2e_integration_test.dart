@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_chat_enums_api.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';

import '../helpers/chat_api_guide_fixtures.dart';
import '../helpers/rschat_e2e_flow.dart';

/// Full rschat journey on production relay (SERVER_API_GUIDE §4).
///
/// Partner Ed25519 sign key (contact / chat identity):
/// `M7KYwZHk4eoqvs23GQ-ITkB_wBbT8gqSvYhEx59ll0o.`
///
/// Run:
/// `flutter test test/integration/rschat_e2e_integration_test.dart --run-skipped`
///
/// Optional env:
/// - `RSCHAT_E2E_MNEMONIC` — 25 words space-separated (sender wallet)
/// - `RSCHAT_E2E_SIGN_KEY_INDEX` — default `0`
/// - `RSCHAT_E2E_PARTNER_SIGN_KEY` — override partner public key
void main() {
  const defaultPartnerSignKey =
      'M7KYwZHk4eoqvs23GQ-ITkB_wBbT8gqSvYhEx59ll0o.';

  final partnerSignKey =
      Platform.environment['RSCHAT_E2E_PARTNER_SIGN_KEY'] ?? defaultPartnerSignKey;

  final signKeyIndex = int.tryParse(
        Platform.environment['RSCHAT_E2E_SIGN_KEY_INDEX'] ?? '4',
      ) ??
      4;

  List<String> senderMnemonic() {
    final fromEnv = Platform.environment['RSCHAT_E2E_MNEMONIC'];
    if (fromEnv != null && fromEnv.trim().isNotEmpty) {
      return fromEnv.trim().split(RegExp(r'\s+'));
    }
    return ChatApiGuideFixtures.guideMnemonic;
  }

  group(
    'rschat E2E — ${TkmChatEnumEnvironments.test.wsUrl}',
    () {
      late RschatE2eFlow flow;

      setUp(() {
        flow = RschatE2eFlow();
      });

      tearDown(() async {
        await flow.disconnect();
      });

      test('connect and nonce only', () async {
        final nonce = await flow.api.getNonce();
        expect(nonce['nonce'], isNotNull);
      }, timeout: const Timeout(Duration(seconds: 30)));

      test('RSA keygen then nonce', () async {
        final seed = await WalletUtils.generateSeedPWH(senderMnemonic());
        await ChatKeyMaterial.fromWalletSeed(seed, signKeyIndex: signKeyIndex);
        final nonce = await flow.api.getNonce();
        expect(nonce['nonce'], isNotNull);
      }, timeout: const Timeout(Duration(seconds: 60)));

      test('requestkeys finds partner on server', () async {
        await flow.registerSession(
          mnemonic: senderMnemonic(),
          signKeyIndex: signKeyIndex,
        );
        var found = false;
        await for (final user in flow.api.requestKeys(
          keys: flow.keys!,
          otherPublicKeys: [partnerSignKey],
        )) {
          expect(user['from'], partnerSignKey);
          expect(
            user.containsKey('register_user_request_signed_content'),
            isTrue,
          );
          found = true;
        }
        expect(found, isTrue, reason: 'partner must be registered on rschat');
      }, timeout: const Timeout(Duration(seconds: 90)));

      test('createconversation with partner only', () async {
        await flow.registerSession(
          mnemonic: senderMnemonic(),
          signKeyIndex: signKeyIndex,
        );
        var partnerBean = <String, dynamic>{};
        await for (final user in flow.api.requestKeys(
          keys: flow.keys!,
          otherPublicKeys: [partnerSignKey],
        )) {
          partnerBean = user;
        }
        expect(partnerBean, isNotEmpty);
        final created = await flow.api.createConversation(
          keys: flow.keys!,
          title: 'E2E partner only',
          members: [partnerBean, flow.registeredUserRequest!],
        );
        expect(created.response['conversation_hash_name'], isNotEmpty);
      }, timeout: const Timeout(Duration(seconds: 90)));

      test('createconversation with self only', () async {
        await flow.registerSession(
          mnemonic: senderMnemonic(),
          signKeyIndex: signKeyIndex,
        );
        final me = flow.registeredUserRequest!;
        try {
          final created = await flow.api.createConversation(
            keys: flow.keys!,
            title: 'E2E self only',
            members: [me],
          );
          expect(created.response['conversation_hash_name'], isNotEmpty);
        } catch (e) {
          fail('createconversation self only: $e');
        }
      }, timeout: const Timeout(Duration(seconds: 90)));

      test('registerSession only', () async {
        await flow.registerSession(
          mnemonic: senderMnemonic(),
          signKeyIndex: signKeyIndex,
        );
        expect(flow.registeredUserRequest, isNotNull);
      }, timeout: const Timeout(Duration(seconds: 90)));

      test('retrieveAllConversations after register', () async {
        await flow.registerSession(
          mnemonic: senderMnemonic(),
          signKeyIndex: signKeyIndex,
        );
        final notBefore =
            DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;
        final hashes = <String>[];
        try {
          await for (final hash in flow.api
              .retrieveAllConversations(keys: flow.keys!, notBefore: notBefore)
              .timeout(const Duration(seconds: 20))) {
            hashes.add(hash);
          }
        } catch (e, st) {
          fail('retrieveAllConversations failed: $e\n$st');
        }
        expect(hashes, isA<List<String>>());
      }, timeout: const Timeout(Duration(seconds: 90)));

      test(
        'register, requestkeys, createconversation, messages to partner',
        () async {
          expect(partnerSignKey.length, 44);
          expect(partnerSignKey.endsWith('.'), isTrue);

          try {
            await flow.registerSession(
              mnemonic: senderMnemonic(),
              signKeyIndex: signKeyIndex,
            );
          } catch (e, st) {
            fail('registerSession failed: $e\n$st');
          }

          final myPk = await flow.mySignPublicKey();
          expect(myPk, isNot(partnerSignKey));

          final title =
              'E2E integration ${DateTime.now().toUtc().toIso8601String()}';
          late ({String conversationHash, String symmetricKey}) chat;
          try {
            chat = await flow.findOrCreateDirectChat(
              title: title,
              partnerSignPublicKey: partnerSignKey,
            );
          } catch (e, st) {
            fail('startDirectChat failed: $e\n$st');
          }

          expect(chat.conversationHash, isNotEmpty);
          expect(chat.symmetricKey.length, 400);

          final messageText =
              'Takamaka SDK E2E ping ${DateTime.now().millisecondsSinceEpoch}';
          late Map<String, dynamic> sendResult;
          try {
            sendResult = await flow.sendTextMessage(
              conversationHash: chat.conversationHash,
              symmetricKey: chat.symmetricKey,
              text: messageText,
            );
          } catch (e, st) {
            fail('sendTextMessage failed: $e\n$st');
          }

          expect(sendResult, isA<Map<String, dynamic>>());
          // Server may return empty map on success; fail only on explicit error keys.
          final error = sendResult['error'] ?? sendResult['message'];
          if (error != null && error.toString().isNotEmpty) {
            fail('messages endpoint error: $sendResult');
          }
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    },
  );
}
