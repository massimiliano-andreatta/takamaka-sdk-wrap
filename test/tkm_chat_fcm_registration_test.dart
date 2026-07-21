import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/constants/chat_message_types.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_crypto.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_canonical_json.dart';

import 'helpers/chat_api_guide_fixtures.dart';

/// FCM token-registration signed request (registerfcmtoken / unregisterfcmtoken).
///
/// The canonical-content assertions below are the CROSS-PLATFORM contract: the
/// exact same golden strings are asserted on the Java side in
/// messages `FcmCanonicalVectorTest`. If either drifts, signature verification
/// against rschat breaks. Fixed input is shared between the two tests.
void main() {
  // Same fixed input as the Java FcmCanonicalVectorTest.
  const fixedNonce = <String, dynamic>{
    'nonce': '11111111-2222-3333-4444-555555555555',
    'timestamp': 1700000000000,
    'liveness': 60000,
  };
  const fixedToken = 'fixed-fcm-token-XYZ';
  const fixedPlatform = 'android';

  const vectorWithDevice =
      '{"device_id":"device-01","fcm_token":"fixed-fcm-token-XYZ","nonce":{"liveness":60000,"nonce":"11111111-2222-3333-4444-555555555555","timestamp":1700000000000},"platform":"android"}';
  const vectorNullDevice =
      '{"device_id":null,"fcm_token":"fixed-fcm-token-XYZ","nonce":{"liveness":60000,"nonce":"11111111-2222-3333-4444-555555555555","timestamp":1700000000000},"platform":"android"}';

  group('FCM token registration — canonical vector parity (matches Java)', () {
    test('device present → byte-identical to Java golden vector', () {
      final content = <String, dynamic>{
        'nonce': fixedNonce,
        'fcm_token': fixedToken,
        'platform': fixedPlatform,
        'device_id': 'device-01',
      };
      expect(TkmCanonicalJson.encode(content), vectorWithDevice);
    });

    test('null device → includes "device_id":null (NOT omitted)', () {
      final content = <String, dynamic>{
        'nonce': fixedNonce,
        'fcm_token': fixedToken,
        'platform': fixedPlatform,
        'device_id': null,
      };
      expect(TkmCanonicalJson.encode(content), vectorNullDevice);
    });
  });

  group('FCM token registration — builder envelope + signature', () {
    late ChatKeyMaterial keys;

    setUp(() async {
      keys = await ChatApiGuideFixtures.guideKeyMaterial();
    });

    Future<void> expectRoundTrip(String? deviceId, String expectedCanonical)
        async {
      final request = await TkmChatCrypto.buildFcmTokenRegistrationRequest(
        keys: keys,
        nonceResponse: fixedNonce,
        fcmToken: fixedToken,
        platform: fixedPlatform,
        deviceId: deviceId,
      );

      expect(request['message_type'], ChatMessageTypes.fcmTokenRegistration);
      expect(request['signature_type'], 'Ed25519BC');
      expect(request.containsKey('fcm_token_registration_signed_content'),
          isTrue);

      final content = request['fcm_token_registration_signed_content']
          as Map<String, dynamic>;
      // builder always carries device_id, even when null
      expect(content.containsKey('device_id'), isTrue);
      expect(content['device_id'], deviceId);

      // the signed content canonicalizes exactly to the server-verified bytes
      final canonical = TkmCanonicalJson.encode(content);
      expect(canonical, expectedCanonical);

      // the signature verifies over that canonical (what rschat checks)
      final valid = await TkmChatSigning.verifyUtf8Message(
        publicKeyUrl64: request['from'] as String,
        signatureUrl64: request['signature'] as String,
        message: canonical,
      );
      expect(valid, isTrue);
    }

    test('registerfcmtoken envelope with device → verifies', () async {
      await expectRoundTrip('device-01', vectorWithDevice);
    });

    test('registerfcmtoken envelope with null device → verifies', () async {
      await expectRoundTrip(null, vectorNullDevice);
    });
  });
}
