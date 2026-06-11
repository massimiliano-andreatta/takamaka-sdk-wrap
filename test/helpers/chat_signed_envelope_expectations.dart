import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_canonical_json.dart';

/// Verifies a rschat [SignedMessageBean]-shaped map (SERVER_API_GUIDE §3).
Future<void> expectValidSignedEnvelope({
  required Map<String, dynamic> envelope,
  required String signedContentKey,
  required String expectedMessageType,
  Object? signedContent,
}) async {
  expect(envelope['signature_type'], TkmChatSigning.signatureType);
  expect(envelope['message_type'], expectedMessageType);
  expect(envelope['from'], isA<String>());
  expect((envelope['from'] as String).length, 44);
  expect(envelope['signature'], isA<String>());
  expect((envelope['signature'] as String).length, 88);
  expect(envelope.containsKey(signedContentKey), isTrue);

  final content = signedContent ?? envelope[signedContentKey];
  final canonical = TkmCanonicalJson.encode(content);
  final valid = await TkmChatSigning.verifyUtf8Message(
    publicKeyUrl64: envelope['from'] as String,
    signatureUrl64: envelope['signature'] as String,
    message: canonical,
  );
  expect(valid, isTrue, reason: 'signature must verify on canonical JSON');
}
