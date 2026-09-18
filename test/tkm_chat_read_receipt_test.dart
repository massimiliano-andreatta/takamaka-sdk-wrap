import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/constants/chat_message_types.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_crypto.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_encryption.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_peer_read_cursor.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_base64_url.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_canonical_json.dart';

import 'helpers/chat_api_guide_fixtures.dart';
import 'helpers/chat_signed_envelope_expectations.dart';

void main() {
  late Map<String, dynamic> vectors;
  late ChatKeyMaterial keys;

  setUpAll(() async {
    vectors = jsonDecode(
      File('test/fixtures/java_read_receipt_vectors.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    keys = await ChatApiGuideFixtures.guideKeyMaterial();
  });

  test('constants match Java READ_RECEIPT vector metadata', () {
    final constants = vectors['read_receipt_constants'] as Map<String, dynamic>;
    expect(ChatMessageTypes.readReceipt, constants['message_type']);
    expect(ChatMessageTypes.readReceipt, constants['scope']);
    expect(TkmChatCrypto.signalProtocolVersion, constants['protocol_version']);
    expect(TkmChatCrypto.receiptCipherVersion, constants['cipher_version']);
  });

  test('encrypt watermark under READ_RECEIPT matches Java ciphertext + JCS',
      () {
    final vector =
        (vectors['encryption_vectors'] as List).first as Map<String, dynamic>;
    final iv = TkmBase64Url.decode(vector['iv_b64url'] as String);
    final encrypted = TkmChatEncryption.encryptUtf8String(
      password: vector['conversation_key'] as String,
      plaintext: vector['watermark_plaintext'] as String,
      scope: ChatMessageTypes.readReceipt,
      iv: iv,
    );
    final em = encrypted['encrypted_message'] as List<dynamic>;
    expect(em[0], vector['iv_b64url']);
    expect(em[1], vector['enc_b64url']);

    final pl = <String, dynamic>{
      'conv': vector['conversation_hash_name'],
      'enc': em[1],
      'iv': em[0],
      'pv': TkmChatCrypto.signalProtocolVersion,
      'v': TkmChatCrypto.receiptCipherVersion,
    };
    expect(TkmCanonicalJson.encode(pl), vector['pl_canonical_jcs']);
  });

  test('Ed25519 over canonical(pl) matches Java signature vector', () async {
    final sigVector = vectors['signature_vector'] as Map<String, dynamic>;
    expect(keys.signKeyIndex, sigVector['key_index']);
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    expect(from, sigVector['signer_public_key']);

    final canonical = sigVector['pl_canonical_jcs'] as String;
    final signature = await TkmChatSigning.signUtf8Message(
      keys.signKeyPair,
      canonical,
    );
    expect(signature, sigVector['signature_b64url']);
  });

  test('buildReadReceiptRequest uses dedicated envelope, not TOPIC_MESSAGE',
      () async {
    final vector =
        (vectors['encryption_vectors'] as List).first as Map<String, dynamic>;
    const lastSig =
        '8otxdmZIe7HY_2ugbRZbAn_lrlxjD_QnCix1w7EpK2DnDaJKgBI98JbGBPR1l7U3jN2ue_dHNLyRUQSFiVRlBg..';
    final request = await TkmChatCrypto.buildReadReceiptRequest(
      keys: keys,
      conversationHash: vector['conversation_hash_name'] as String,
      symmetricKey: vector['conversation_key'] as String,
      lastReadMessageSignature: lastSig,
    );

    await expectValidSignedEnvelope(
      envelope: request,
      signedContentKey: 'pl',
      expectedMessageType: ChatMessageTypes.readReceipt,
    );
    expect(request.containsKey('basic_message_signed_content_bean'), isFalse);

    final pl = request['pl'] as Map<String, dynamic>;
    expect(pl.keys.toList()..sort(), ['conv', 'enc', 'iv', 'pv', 'v']);
    expect(pl['pv'], '1.0');
    expect(pl['v'], 'v0_1_a');

    final watermark = await TkmChatCrypto.decryptReadReceiptWatermark(
      envelope: request,
      symmetricKey: vector['conversation_key'] as String,
    );
    expect(watermark, lastSig);
  });

  test('buildRetrieveReadReceiptsRequest signs nonce + not_before', () async {
    final request = await TkmChatCrypto.buildRetrieveReadReceiptsRequest(
      keys: keys,
      nonceResponse: ChatApiGuideFixtures.guideNonceResponse(),
      notBefore: 1706000000000,
    );
    await expectValidSignedEnvelope(
      envelope: request,
      signedContentKey: 'pl',
      expectedMessageType: ChatMessageTypes.retrieveReadReceipts,
    );
    final pl = request['pl'] as Map<String, dynamic>;
    expect(pl['not_before'], 1706000000000);
    expect(pl['nonce'], ChatApiGuideFixtures.guideNonceResponse());
  });

  test('PeerReadCursor merge matches Java merge vectors', () {
    final mergeVectors = vectors['merge_vectors'] as List<dynamic>;
    for (final raw in mergeVectors) {
      final vector = raw as Map<String, dynamic>;
      final initial = vector['initial'] as Map<String, dynamic>;
      var cursor = TkmPeerReadCursor(
        lastReadMessageSignature:
            initial['lastReadMessageSignature'] as String?,
        lastReadTimestamp: initial['lastReadTimestamp'] as int?,
      );
      final result = cursor.merge(
        candidateSignature: vector['candidate_signature'] as String,
        candidateTimestamp: vector['candidate_timestamp'] as int,
      );
      expect(result.advanced, vector['expected_advanced'],
          reason: vector['desc'] as String);
      final expected = vector['expected_cursor'] as Map<String, dynamic>;
      expect(
        result.cursor.lastReadMessageSignature,
        expected['lastReadMessageSignature'],
        reason: vector['desc'] as String,
      );
      expect(
        result.cursor.lastReadTimestamp,
        expected['lastReadTimestamp'],
        reason: vector['desc'] as String,
      );
    }
  });
}
