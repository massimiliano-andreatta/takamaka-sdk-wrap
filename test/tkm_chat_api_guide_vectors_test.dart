import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/constants/chat_message_types.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_crypto.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_chat_enums_api.dart';

import 'helpers/chat_api_guide_fixtures.dart';
import 'helpers/chat_signed_envelope_expectations.dart';

/// Cross-platform vectors and registeruser shape from SERVER_API_GUIDE.pdf §3.2 / §5.2.
void main() {
  group('SERVER_API_GUIDE §3.2 — Ed25519 cross-platform vector', () {
    test('derives guide public key at wallet index 4', () async {
      final keyPair = await ChatApiGuideFixtures.guideSignKeyPair();
      final publicKey = await TkmChatSigning.publicKeyUrl64(keyPair);
      expect(publicKey, ChatApiGuideFixtures.guidePublicKeyUrl64);
    });

    test('reproduces known signature on canonical JSON', () async {
      final keyPair = await ChatApiGuideFixtures.guideSignKeyPair();
      final signature = await TkmChatSigning.signUtf8Message(
        keyPair,
        ChatApiGuideFixtures.guideSignatureMessage,
      );
      expect(signature, ChatApiGuideFixtures.guideSignatureUrl64);
      expect(signature.length, 88);

      final valid = await TkmChatSigning.verifyUtf8Message(
        publicKeyUrl64: ChatApiGuideFixtures.guidePublicKeyUrl64,
        signatureUrl64: signature,
        message: ChatApiGuideFixtures.guideSignatureMessage,
      );
      expect(valid, isTrue);
    });
  });

  group('SERVER_API_GUIDE §5.2 — registeruser signed envelope', () {
    test('buildRegisterUserRequest matches SignedMessageBean contract', () async {
      final keys = await ChatApiGuideFixtures.guideKeyMaterial();
      final request = await TkmChatCrypto.buildRegisterUserRequest(
        keys: keys,
        nonceResponse: ChatApiGuideFixtures.guideNonceResponse(),
      );

      await expectValidSignedEnvelope(
        envelope: request,
        signedContentKey: 'register_user_request_signed_content',
        expectedMessageType: ChatMessageTypes.registerUserSignedRequest,
      );

      expect(request['from'], ChatApiGuideFixtures.guidePublicKeyUrl64);

      final content = request['register_user_request_signed_content']
          as Map<String, dynamic>;
      expect(content['encryption_public_key_type'], 'RSA_4096_ECB_OAEP_SHA256');
      expect(content['encryption_public_key'], keys.rsaPublicKeyUrl64);
      expect(content['encryption_public_key'].toString().length, greaterThan(700));

      final nonce = content['nonce'] as Map<String, dynamic>;
      expect(nonce['nonce'], ChatApiGuideFixtures.guideNonceResponse()['nonce']);
      expect(nonce['liveness'], 900000);
    });
  });

  group('SERVER_API_GUIDE §2.1 — WebSocket endpoint', () {
    test('test and production use /rschat path on rschat host', () {
      for (final env in TkmChatEnumEnvironments.values) {
        expect(env.wsUrl, startsWith('wss://'));
        expect(env.wsUrl, endsWith('/rschat'));
        expect(env.wsUrl, contains('rschat.takamaka.org'));
      }
    });
  });
}
