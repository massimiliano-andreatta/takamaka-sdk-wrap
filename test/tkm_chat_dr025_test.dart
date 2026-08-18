import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/constants/chat_message_types.dart';
import 'package:takamaka_sdk_wrap/constants/chat_server_endpoints.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_crypto.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_delete_honor.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_inbound_envelope.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_manifest_limits.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_canonical_json.dart';

import 'helpers/chat_api_guide_fixtures.dart';

void main() {
  late ChatKeyMaterial keys;

  setUp(() async {
    keys = await ChatApiGuideFixtures.guideKeyMaterial();
  });

  group('DR-025 canonical(pl) vs Java vectors', () {
    late List<dynamic> deleteVectors;
    late List<dynamic> retrieveVectors;

    setUpAll(() {
      deleteVectors = (jsonDecode(
        File('test/fixtures/java_delete_message_vectors.json')
            .readAsStringSync(),
      ) as Map)['delete_vectors'] as List<dynamic>;
      retrieveVectors = (jsonDecode(
        File('test/fixtures/java_retrieve_deletions_vectors.json')
            .readAsStringSync(),
      ) as Map)['request_vectors'] as List<dynamic>;
    });

    Map<String, dynamic> plFromDeleteInput(Map<String, dynamic> input) {
      final pl = <String, dynamic>{
        'conversation_hash_name': input['conversation_hash_name'],
        'target_message_signature': input['target_message_signature'],
        if (input['client_ts'] != null) 'client_ts': input['client_ts'],
      };
      final efh = input['target_efh'];
      if (efh is List && efh.isNotEmpty) {
        pl['target_efh'] = efh;
      }
      final reason = input['reason'];
      if (reason is Map && reason.isNotEmpty) {
        pl['reason'] = reason;
      }
      return pl;
    }

    test('delete vectors canonicalize like the Java sign unit', () {
      for (final raw in deleteVectors) {
        final vector = raw as Map<String, dynamic>;
        final pl = plFromDeleteInput(vector['input'] as Map<String, dynamic>);
        expect(
          TkmCanonicalJson.encode(pl),
          vector['pl_canonical_jcs'],
          reason: 'canonical(pl) mismatch for "${vector['desc']}"',
        );
      }
    });

    test('retrieve-deletions vectors omit null since (NON_EMPTY)', () {
      for (final raw in retrieveVectors) {
        final vector = raw as Map<String, dynamic>;
        final input = vector['input'] as Map<String, dynamic>;
        final pl = <String, dynamic>{
          'conversation_hash_name': input['conversation_hash_name'],
          if (input['client_ts'] != null) 'client_ts': input['client_ts'],
        };
        if (input['since'] != null) {
          pl['since'] = input['since'];
        }
        expect(
          TkmCanonicalJson.encode(pl),
          vector['pl_canonical_jcs'],
          reason: 'canonical(pl) mismatch for "${vector['desc']}"',
        );
      }
    });
  });

  group('DR-025 signed envelopes', () {
    const parentSignature =
        '8otxdmZIe7HY_2ugbRZbAn_lrlxjD_QnCix1w7EpK2DnDaJKgBI98JbGBPR1l7U3jN2ue_dHNLyRUQSFiVRlBg..';

    test('deletemessage envelope uses pl and DELETE_MESSAGE', () async {
      final request = await TkmChatCrypto.buildDeleteMessageRequest(
        keys: keys,
        conversationHash: 'conv-hash-guide-test',
        targetMessageSignature: parentSignature,
        clientTimestamp: 1767225600000,
      );
      expect(request['message_type'], ChatMessageTypes.deleteMessage);
      expect(request['signature_type'], TkmChatSigning.signatureType);
      final pl = request['pl'] as Map<String, dynamic>;
      expect(pl.containsKey('target_efh'), isFalse);
      expect(pl.containsKey('reason'), isFalse);
      expect(
        await TkmChatSigning.verifyCanonicalJsonJavaCompatible(
          publicKeyUrl64: request['from'] as String,
          signatureUrl64: request['signature'] as String,
          signedContent: pl,
        ),
        isTrue,
      );
    });

    test('retrievedeletions omits null since and includes since=0', () async {
      final absent = await TkmChatCrypto.buildRetrieveDeletionsRequest(
        keys: keys,
        conversationHash: 'conv-hash-guide-test',
        clientTimestamp: 1767225600000,
      );
      expect(absent['message_type'], ChatMessageTypes.retrieveDeletions);
      expect(
        (absent['pl'] as Map).containsKey('since'),
        isFalse,
      );

      final zero = await TkmChatCrypto.buildRetrieveDeletionsRequest(
        keys: keys,
        conversationHash: 'conv-hash-guide-test',
        since: 0,
        clientTimestamp: 1767225600000,
      );
      expect((zero['pl'] as Map)['since'], 0);
      expect(
        TkmCanonicalJson.encode(absent['pl']),
        isNot(TkmCanonicalJson.encode(zero['pl'])),
      );
    });
  });

  group('inbound envelope + honor', () {
    const parentSignature =
        '8otxdmZIe7HY_2ugbRZbAn_lrlxjD_QnCix1w7EpK2DnDaJKgBI98JbGBPR1l7U3jN2ue_dHNLyRUQSFiVRlBg..';

    test('classifies DELETE_MESSAGE vs TOPIC_MESSAGE', () async {
      final delete = await TkmChatCrypto.buildDeleteMessageRequest(
        keys: keys,
        conversationHash: 'conv-hash-guide-test',
        targetMessageSignature: parentSignature,
        clientTimestamp: 1767225600000,
      );
      final inbound = TkmInboundEnvelope.fromJson(delete);
      expect(inbound.isDelete, isTrue);
      expect(inbound.targetMessageSignature, parentSignature);
      expect(inbound.conversationHashName, 'conv-hash-guide-test');

      final messageJson = jsonEncode({
        'from': 'abc.',
        'signature': parentSignature,
        'message_type': ChatMessageTypes.topicMessage,
        'signature_type': 'Ed25519BC',
        'basic_message_signed_content_bean': {
          'conversation_hash_name': 'conv-hash-guide-test',
        },
      });
      expect(TkmInboundEnvelope.parse(messageJson).isMessage, isTrue);
    });

    test('empty history tombstone is malformed, not a message', () {
      expect(
        TkmInboundEnvelope.parse('').kind,
        TkmInboundEnvelopeKind.malformed,
      );
    });

    test('honor applies owner-signed delete and rejects non-owner', () async {
      final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
      final delete = await TkmChatCrypto.buildDeleteMessageRequest(
        keys: keys,
        conversationHash: 'conv-hash-guide-test',
        targetMessageSignature: parentSignature,
        clientTimestamp: 1767225600000,
      );
      final inbound = TkmInboundEnvelope.fromJson(delete);

      final honored = await TkmChatDeleteHonor.honor(
        inbound,
        targetMessageAuthor: from,
      );
      expect(honored.shouldApply, isTrue);
      expect(honored.tombstone?.targetMessageSignature, parentSignature);

      final notOwner = await TkmChatDeleteHonor.honor(
        inbound,
        targetMessageAuthor: 'someone-else.',
      );
      expect(notOwner.outcome, TkmDeleteHonorOutcome.notOwner);

      final skipped = await TkmChatDeleteHonor.honor(
        inbound,
        targetMessageAuthor: from,
        selfPublicKey: from,
        skipSelfAuthored: true,
      );
      expect(skipped.outcome, TkmDeleteHonorOutcome.selfAuthored);
    });
  });

  group('DR-022 manifest limits', () {
    test('absent advertisement uses conservative default chunk', () {
      final resolution = TkmChatManifestLimits.resolve(
        0,
        TkmChatManifestLimits.mobileUploadTargetBytes,
      );
      expect(resolution.reason, TkmChatManifestReason.absent);
      expect(resolution.uploadChunkBytes, lessThanOrEqualTo(56 * 1024));
      expect(resolution.uploadChunkBytes, greaterThanOrEqualTo(16 * 1024));
    });

    test('mobile target is capped by advertised ceiling', () {
      final resolution = TkmChatManifestLimits.resolve(
        2 * 1024 * 1024,
        TkmChatManifestLimits.mobileUploadTargetBytes,
      );
      expect(resolution.reason, TkmChatManifestReason.ok);
      expect(
        resolution.uploadChunkBytes,
        TkmChatManifestLimits.mobileUploadTargetBytes,
      );
    });

    test('route names match rsclient', () {
      expect(ChatServerEndpoints.deleteMessage, 'deletemessage');
      expect(ChatMessageTypes.deleteMessage, 'DELETE_MESSAGE');
    });
  });
}
