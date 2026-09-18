import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/constants/chat_message_types.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_crypto.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_canonical_json.dart';

import 'helpers/chat_api_guide_fixtures.dart';
import 'helpers/chat_signed_envelope_expectations.dart';

/// Cross-language golden vector for FCM token registration signed content.
///
/// Aligned with Java `FcmCanonicalVectorTest` and
/// `docs/guide/FCM_PUSH_CLIENT_FLUTTER.en.pdf` §3.
void main() {
  const expectedCanonical =
      '{"device_id":null,"fcm_token":"fixed-fcm-token-XYZ",'
      '"nonce":{"liveness":60000,"nonce":"11111111-2222-3333-4444-555555555555",'
      '"timestamp":1700000000000},"platform":"android"}';

  Map<String, dynamic> fixedNonce() => {
        'nonce': '11111111-2222-3333-4444-555555555555',
        'timestamp': 1700000000000,
        'liveness': 60000,
      };

  test('canonical JSON keeps device_id:null (never omits the key)', () {
    final content = <String, dynamic>{
      'nonce': fixedNonce(),
      'fcm_token': 'fixed-fcm-token-XYZ',
      'platform': 'android',
      'device_id': null,
    };
    expect(TkmCanonicalJson.encode(content), expectedCanonical);
  });

  test('omitting device_id produces a different canonical string', () {
    final withoutKey = <String, dynamic>{
      'nonce': fixedNonce(),
      'fcm_token': 'fixed-fcm-token-XYZ',
      'platform': 'android',
    };
    expect(TkmCanonicalJson.encode(withoutKey), isNot(expectedCanonical));
  });

  test('buildFcmTokenRegistrationRequest includes null device_id', () async {
    final keys = await ChatApiGuideFixtures.guideKeyMaterial();
    final request = await TkmChatCrypto.buildFcmTokenRegistrationRequest(
      keys: keys,
      nonceResponse: fixedNonce(),
      fcmToken: 'fixed-fcm-token-XYZ',
      platform: 'android',
      deviceId: null,
    );

    await expectValidSignedEnvelope(
      envelope: request,
      signedContentKey: 'fcm_token_registration_signed_content',
      expectedMessageType: ChatMessageTypes.fcmTokenRegistration,
    );

    final content =
        request['fcm_token_registration_signed_content'] as Map<String, dynamic>;
    expect(content.containsKey('device_id'), isTrue);
    expect(content['device_id'], isNull);
    expect(TkmCanonicalJson.encode(content), expectedCanonical);
  });
}
