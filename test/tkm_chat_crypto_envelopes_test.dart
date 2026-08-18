import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/constants/chat_message_types.dart';
import 'package:takamaka_sdk_wrap/constants/chat_server_endpoints.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_crypto.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_rsa.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_canonical_json.dart';

import 'helpers/chat_api_guide_fixtures.dart';
import 'helpers/chat_signed_envelope_expectations.dart';

/// Signed request envelopes per SERVER_API_GUIDE.pdf §3 route table.
void main() {
  late ChatKeyMaterial keys;

  setUp(() async {
    keys = await ChatApiGuideFixtures.guideKeyMaterial();
  });

  group('signed envelopes — route / field / message_type', () {
    test('requestkeys — REQUEST_USER_KEYS', () async {
      final request = await TkmChatCrypto.buildRequestKeysRequest(
        keys: keys,
        otherUserSignKeys: const [
          'RZfhCW4uWldE6DUP_9rs_vaqNkCyiqORYZwdQrkHJww.',
        ],
      );

      expect(request['message_type'], ChatMessageTypes.requestUserKeys);
      expect(request['signature_type'], 'Ed25519BC');
      expect(
          request.containsKey('request_user_key_request_bean_signed_content'),
          isTrue);

      final items = request['request_user_key_request_bean_signed_content']
          as List<dynamic>;
      expect(items, hasLength(1));
      expect(items.first['other_user_sign_key'],
          'RZfhCW4uWldE6DUP_9rs_vaqNkCyiqORYZwdQrkHJww.');

      final canonical = TkmCanonicalJson.encode(items);
      final valid = await TkmChatSigning.verifyUtf8Message(
        publicKeyUrl64: request['from'] as String,
        signatureUrl64: request['signature'] as String,
        message: canonical,
      );
      expect(valid, isTrue);
    });

    test('createconversation — TOPIC_CREATION', () async {
      final memberRegister = await TkmChatCrypto.buildRegisterUserRequest(
        keys: keys,
        nonceResponse: ChatApiGuideFixtures.guideNonceResponse(),
      );

      final request = await TkmChatCrypto.buildCreateConversationRequest(
        keys: keys,
        title: 'Guide test topic',
        memberRegisterBeans: [memberRegister],
      );

      await expectValidSignedEnvelope(
        envelope: request,
        signedContentKey: 'topic',
        expectedMessageType: ChatMessageTypes.topicCreation,
      );

      final topic = request['topic'] as Map<String, dynamic>;
      final desc = topic['topic_description'] as Map<String, dynamic>;
      expect(desc['em'], isA<List>());
      expect(desc['tv'], 'v0_1_a');
      expect(desc['pa'], 'PBKDF2WithHmacSHA512');
      expect(desc['ka'], 'AES');
      expect(topic['topic_members_map'], isA<Map<String, dynamic>>());
    });

    test('messages — TOPIC_MESSAGE', () async {
      const conversationHash = 'conv-hash-guide-test';
      const symKey = 'symmetric-key-password-for-aes-scope-test-0123456789';
      final request = await TkmChatCrypto.buildBasicMessageRequest(
        keys: keys,
        conversationHash: conversationHash,
        symmetricKey: symKey,
        text: 'Hello from unit test',
        citedUsers: const ['el3xvxJnLv9S9aWD0ei3g96YGOAvdYW_yn5z1eIvCDc.'],
      );

      await expectValidSignedEnvelope(
        envelope: request,
        signedContentKey: 'basic_message_signed_content_bean',
        expectedMessageType: ChatMessageTypes.topicMessage,
      );

      final content =
          request['basic_message_signed_content_bean'] as Map<String, dynamic>;
      expect(content['conversation_hash_name'], conversationHash);
      expect(content['encrypted_content'], isA<Map<String, dynamic>>());
    });

    test('retrievemessages stream — SIGNED_TIMESTAMP', () async {
      final request =
          await TkmChatCrypto.buildSignedTimestampRequest(keys: keys);

      await expectValidSignedEnvelope(
        envelope: request,
        signedContentKey: 'signed_timestamp',
        expectedMessageType: ChatMessageTypes.signedTimestamp,
      );
      expect(
        ChatServerEndpoints.retrieveMessages,
        'retrievemessages',
      );
    });

    test('retrieveallconversations — RETRIEVE_ALL_CONVERSATIONS_REQUEST',
        () async {
      final request = await TkmChatCrypto.buildRetrieveAllConversationsRequest(
        keys: keys,
        notBefore: 1706000000000,
      );

      await expectValidSignedEnvelope(
        envelope: request,
        signedContentKey: 'all_conversations',
        expectedMessageType: ChatMessageTypes.retrieveAllConversations,
      );
    });

    test('retrieveconversation — RETRIEVE_CONVERSATION_REQUEST', () async {
      final request = await TkmChatCrypto.buildRetrieveConversationRequest(
        keys: keys,
        conversationHash: 'abc123',
      );

      await expectValidSignedEnvelope(
        envelope: request,
        signedContentKey: 'conversation',
        expectedMessageType: ChatMessageTypes.retrieveConversation,
      );
    });

    test('notification — NOTIFICATION_REQUEST', () async {
      final request = await TkmChatCrypto.buildNotificationRequest(
        keys: keys,
        notBefore: 1706000000000,
        onlyUnread: true,
      );

      await expectValidSignedEnvelope(
        envelope: request,
        signedContentKey: 'signed_content',
        expectedMessageType: ChatMessageTypes.notificationRequest,
      );
    });

    test('reply message — action reply + targets in encrypted inner plaintext',
        () async {
      const conversationHash = 'conv-hash-guide-test';
      const symKey = 'symmetric-key-password-for-aes-scope-test-0123456789';
      const parentSignature =
          '8otxdmZIe7HY_2ugbRZbAn_lrlxjD_QnCix1w7EpK2DnDaJKgBI98JbGBPR1l7U3jN2ue_dHNLyRUQSFiVRlBg..';
      final request = await TkmChatCrypto.buildReplyMessageRequest(
        keys: keys,
        conversationHash: conversationHash,
        symmetricKey: symKey,
        parentMessageSignature: parentSignature,
        text: 'a reply',
      );

      await expectValidSignedEnvelope(
        envelope: request,
        signedContentKey: 'basic_message_signed_content_bean',
        expectedMessageType: ChatMessageTypes.topicMessage,
      );

      final decrypted = TkmChatCrypto.decryptContentFromMessageEnvelope(
        envelope: request,
        symmetricKey: symKey,
      );
      expect(decrypted, isNotNull);
      final action = TkmChatCrypto.parseMessageActionFields(decrypted!);
      expect(action.action, 'reply');
      expect(action.targets, [parentSignature]);
    });

    test('reaction message — SHA3-256 hash over preview base64 string',
        () async {
      const conversationHash = 'conv-hash-guide-test';
      const symKey = 'symmetric-key-password-for-aes-scope-test-0123456789';
      const parentSignature =
          '8otxdmZIe7HY_2ugbRZbAn_lrlxjD_QnCix1w7EpK2DnDaJKgBI98JbGBPR1l7U3jN2ue_dHNLyRUQSFiVRlBg..';
      final request = await TkmChatCrypto.buildReactionMessageRequest(
        keys: keys,
        conversationHash: conversationHash,
        symmetricKey: symKey,
        parentMessageSignature: parentSignature,
        emoji: '👍',
      );

      await expectValidSignedEnvelope(
        envelope: request,
        signedContentKey: 'basic_message_signed_content_bean',
        expectedMessageType: ChatMessageTypes.topicMessage,
      );

      final decrypted = TkmChatCrypto.decryptContentFromMessageEnvelope(
        envelope: request,
        symmetricKey: symKey,
      );
      expect(decrypted, isNotNull);
      final action = TkmChatCrypto.parseMessageActionFields(decrypted!);
      expect(action.action, 'reaction');
      expect(action.reactionEmoji, '👍');
    });

    test('retrieveallmessages — LAST_N history request', () async {
      final request = await TkmChatCrypto.buildRetrieveMessageHistoryRequest(
        keys: keys,
        conversationHash: 'EgQQ-z73-test-hash-name-lFA.',
        limit: 50,
      );

      await expectValidSignedEnvelope(
        envelope: request,
        signedContentKey: 'signed_request',
        expectedMessageType: ChatMessageTypes.retrieveMessageLastN,
      );

      final content = request['signed_request'] as Map<String, dynamic>;
      expect(content['number_of_messages'], 50);
      expect(content['conversation_hash_name'], 'EgQQ-z73-test-hash-name-lFA.');
      expect(content.containsKey('last_message_signature'), isFalse);
    });

    test('retrieveallmessages — BY_SIGNATURE pagination request', () async {
      const lastSig =
          '8otxdmZIe7HY_2ugbRZbAn_lrlxjD_QnCix1w7EpK2DnDaJKgBI98JbGBPR1l7U3jN2ue_dHNLyRUQSFiVRlBg..';
      final request = await TkmChatCrypto.buildRetrieveMessageHistoryRequest(
        keys: keys,
        conversationHash: 'EgQQ-z73-test-hash-name-lFA.',
        limit: 50,
        afterMessageSignature: lastSig,
      );

      expect(
        request['message_type'],
        ChatMessageTypes.retrieveMessageBySignature,
      );
      final content = request['signed_request'] as Map<String, dynamic>;
      expect(content['last_message_signature'], lastSig);
    });

    test('edit message — action edit in inner plaintext', () async {
      const conversationHash = 'conv-hash-guide-test';
      const symKey = 'symmetric-key-password-for-aes-scope-test-0123456789';
      const parentSignature =
          '8otxdmZIe7HY_2ugbRZbAn_lrlxjD_QnCix1w7EpK2DnDaJKgBI98JbGBPR1l7U3jN2ue_dHNLyRUQSFiVRlBg..';
      final request = await TkmChatCrypto.buildEditMessageRequest(
        keys: keys,
        conversationHash: conversationHash,
        symmetricKey: symKey,
        parentMessageSignature: parentSignature,
        newText: 'edited text',
      );

      await expectValidSignedEnvelope(
        envelope: request,
        signedContentKey: 'basic_message_signed_content_bean',
        expectedMessageType: ChatMessageTypes.topicMessage,
      );

      final decrypted = TkmChatCrypto.decryptContentFromMessageEnvelope(
        envelope: request,
        symmetricKey: symKey,
      );
      final action = TkmChatCrypto.parseMessageActionFields(decrypted!);
      expect(action.action, 'edit');
      expect(action.targets, [parentSignature]);
    });

    test('typing subscribe — TYPING_SUBSCRIBE signed pl', () async {
      final request = await TkmChatCrypto.buildTypingSubscribeRequest(
        keys: keys,
        clientTimestamp: 1706000000000,
      );

      await expectValidSignedEnvelope(
        envelope: request,
        signedContentKey: 'pl',
        expectedMessageType: ChatMessageTypes.typingSubscribe,
      );

      final pl = request['pl'] as Map<String, dynamic>;
      expect(pl['pv'], TkmChatCrypto.signalProtocolVersion);
      expect(pl['ts'], 1706000000000);
      expect(pl.containsKey('from'), isFalse);

      final emit = TkmChatCrypto.buildTypingEmitPayload(
        conversationHash: 'conv-hash-guide-test',
      );
      expect(emit['conv'], 'conv-hash-guide-test');
      expect(emit['pv'], TkmChatCrypto.signalProtocolVersion);
      expect(emit.containsKey('from'), isFalse);
    });

    test('pin message — action pin + target in inner plaintext', () async {
      const conversationHash = 'conv-hash-guide-test';
      const symKey = 'symmetric-key-password-for-aes-scope-test-0123456789';
      const targetSignature =
          '8otxdmZIe7HY_2ugbRZbAn_lrlxjD_QnCix1w7EpK2DnDaJKgBI98JbGBPR1l7U3jN2ue_dHNLyRUQSFiVRlBg..';
      final request = await TkmChatCrypto.buildPinMessageRequest(
        keys: keys,
        conversationHash: conversationHash,
        symmetricKey: symKey,
        targetMessageSignature: targetSignature,
        note: 'pinned note',
      );

      final decrypted = TkmChatCrypto.decryptContentFromMessageEnvelope(
        envelope: request,
        symmetricKey: symKey,
      );
      final action = TkmChatCrypto.parseMessageActionFields(decrypted!);
      expect(action.action, 'pin');
      expect(action.targets, [targetSignature]);
    });

    test('unpin message — action unpin without targets', () async {
      const conversationHash = 'conv-hash-guide-test';
      const symKey = 'symmetric-key-password-for-aes-scope-test-0123456789';
      final request = await TkmChatCrypto.buildUnpinMessageRequest(
        keys: keys,
        conversationHash: conversationHash,
        symmetricKey: symKey,
      );

      final decrypted = TkmChatCrypto.decryptContentFromMessageEnvelope(
        envelope: request,
        symmetricKey: symKey,
      );
      final action = TkmChatCrypto.parseMessageActionFields(decrypted!);
      expect(action.action, 'unpin');
      expect(action.targets, isEmpty);
    });

    test('forward message — fw_content nested in inner plaintext', () async {
      const conversationHash = 'conv-hash-guide-test';
      const symKey = 'symmetric-key-password-for-aes-scope-test-0123456789';
      final request = await TkmChatCrypto.buildForwardMessageRequest(
        keys: keys,
        conversationHash: conversationHash,
        symmetricKey: symKey,
        contentToForward: const {'text_message': 'forwarded body'},
        forwarderNote: 'fyi',
        claimedOriginPublicKey: '9xIsD_XELYretqJPxcXdDD1qIFGe5v-2mOktmIjRaTo.',
      );

      final decrypted = TkmChatCrypto.decryptContentFromMessageEnvelope(
        envelope: request,
        symmetricKey: symKey,
      );
      final action = TkmChatCrypto.parseMessageActionFields(decrypted!);
      expect(action.action, 'forward');
      expect(action.fwContent?['text_message'], 'forwarded body');
      expect(action.targets, ['9xIsD_XELYretqJPxcXdDD1qIFGe5v-2mOktmIjRaTo.']);
    });

    test('share_history — embeds original envelope', () async {
      const conversationHash = 'conv-hash-guide-test';
      const symKey = 'symmetric-key-password-for-aes-scope-test-0123456789';
      final original = await TkmChatCrypto.buildBasicMessageRequest(
        keys: keys,
        conversationHash: conversationHash,
        symmetricKey: symKey,
        text: 'original body',
      );

      final request = await TkmChatCrypto.buildShareHistoryMessageRequest(
        keys: keys,
        conversationHash: conversationHash,
        symmetricKey: symKey,
        originalEnvelope: original,
        relayerNote: 'sharing history',
      );

      final decrypted = TkmChatCrypto.decryptContentFromMessageEnvelope(
        envelope: request,
        symmetricKey: symKey,
      );
      final action = TkmChatCrypto.parseMessageActionFields(decrypted!);
      expect(action.action, 'share_history');
      expect(action.originalMessage?['signature'], original['signature']);
      expect(action.reShared, isFalse);
    });

    test('redact message — optional reason omitted when empty', () async {
      const conversationHash = 'conv-hash-guide-test';
      const symKey = 'symmetric-key-password-for-aes-scope-test-0123456789';
      const parentSignature =
          '8otxdmZIe7HY_2ugbRZbAn_lrlxjD_QnCix1w7EpK2DnDaJKgBI98JbGBPR1l7U3jN2ue_dHNLyRUQSFiVRlBg..';
      final request = await TkmChatCrypto.buildRedactMessageRequest(
        keys: keys,
        conversationHash: conversationHash,
        symmetricKey: symKey,
        parentMessageSignature: parentSignature,
      );

      final decrypted = TkmChatCrypto.decryptContentFromMessageEnvelope(
        envelope: request,
        symmetricKey: symKey,
      );
      expect(decrypted!.containsKey('text_message'), isFalse);
      expect(decrypted['action'], 'redact');
    });

    test('retrieveattachment — DOWNLOAD_REQUEST envelope', () async {
      final request = await TkmChatCrypto.buildSignedDownloadRequest(
        keys: keys,
        conversationHash: 'EgQQ-z73-test-hash-name-lFA.',
        uploadContentIdentifyingHash: 'test-content-hash-12345',
      );

      await expectValidSignedEnvelope(
        envelope: request,
        signedContentKey: 'download_request',
        expectedMessageType: ChatMessageTypes.downloadRequest,
      );
    });
  });

  group('topic key invite decrypt round-trip', () {
    test('RSA invite encrypts symmetric key recoverable by member', () async {
      final memberRegister = await TkmChatCrypto.buildRegisterUserRequest(
        keys: keys,
        nonceResponse: ChatApiGuideFixtures.guideNonceResponse(),
      );

      final request = await TkmChatCrypto.buildCreateConversationRequest(
        keys: keys,
        title: 'Invite test',
        memberRegisterBeans: [memberRegister],
      );

      final topic = request['topic'] as Map<String, dynamic>;
      final invitations = (topic['topic_members_map']
              as Map<String, dynamic>)['topic_invitation_list']
          as Map<String, dynamic>;
      final invite = invitations.values.first as Map<String, dynamic>;

      final decrypted = TkmChatCrypto.decryptSymmetricInvite(
        keys: keys,
        invite: invite,
      );
      expect(decrypted, isNotEmpty);
      expect(decrypted.length, 400);
      expect(TkmChatRsaKeyPair.decodePublicKey(keys.rsaPublicKeyUrl64).modulus,
          isNotNull);
    });

    test('symmetricKeyFromTopic tries wallet-derived RSA fallback', () async {
      final memberRegister = await TkmChatCrypto.buildRegisterUserRequest(
        keys: keys,
        nonceResponse: ChatApiGuideFixtures.guideNonceResponse(),
      );

      final request = await TkmChatCrypto.buildCreateConversationRequest(
        keys: keys,
        title: 'Fallback RSA test',
        memberRegisterBeans: [memberRegister],
      );

      final topic = request['topic'] as Map<String, dynamic>;
      final wrongRsa = await TkmChatRsaKeyPair.generate();
      final keysWithFallback = ChatKeyMaterial(
        signKeyPair: keys.signKeyPair,
        rsaKeyPair: wrongRsa,
        rsaKeyFallbacks: [keys.rsaKeyPair],
        signKeyIndex: keys.signKeyIndex,
      );

      final resolved = await TkmChatCrypto.symmetricKeyFromTopic(
        keys: keysWithFallback,
        topic: topic,
      );

      expect(resolved.error, isNull);
      expect(resolved.symmetricKey, isNotEmpty);
      expect(resolved.resolvedRsaKey, keys.rsaKeyPair);
    });
  });

  group('stream event parsing helpers', () {
    test(
        'topicFromRetrieveConversationResponse — nested create_conversation_request',
        () {
      const topic = {
        'topic_members_map': {
          'topic_invitation_list': {'pk1': 'invite'},
        },
      };
      final detail = {
        'conversation_hash_name': 'hash-1',
        'create_conversation_request': {'topic': topic},
      };
      expect(
        TkmChatCrypto.topicFromRetrieveConversationResponse(detail),
        topic,
      );
    });

    test('conversationCreatorPublicKeyFromDetail — create request from', () {
      final detail = {
        'create_conversation_request': {
          'from': '9xIsD_XELYretqJPxcXdDD1qIFGe5v-2mOktmIjRaTo.',
          'topic': {'topic_members_map': {}},
        },
      };
      expect(
        TkmChatCrypto.conversationCreatorPublicKeyFromDetail(detail),
        '9xIsD_XELYretqJPxcXdDD1qIFGe5v-2mOktmIjRaTo.',
      );
    });

    test('topicFromRetrieveConversationResponse — direct topic field', () {
      const topic = {
        'topic_description': {'scope': 'TOPIC_CREATION'},
      };
      final detail = {'topic': topic};
      expect(
        TkmChatCrypto.topicFromRetrieveConversationResponse(detail),
        topic,
      );
    });

    test('invitationListFromTopic — single sanitized invite entry', () {
      const invite = {
        'enc_key_hash': 'hash-a',
        'enc_key': 'cipher-a',
      };
      final topic = {
        'topic_members_map': {
          'topic_invitation_list': {'member-pk': invite},
        },
      };
      expect(
        TkmChatCrypto.invitationListFromTopic(topic),
        {'member-pk': invite},
      );
    });

    test('envelopeFromStreamEvent — message_json string and map', () {
      const envelope = {
        'from': 'sender-pk',
        'basic_message_signed_content_bean': {
          'conversation_hash_name': 'hash-1',
        },
      };
      final fromString = TkmChatCrypto.envelopeFromStreamEvent({
        'request_signature': 'sig-1',
        'message_json': jsonEncode(envelope),
      });
      expect(fromString?['from'], 'sender-pk');

      final fromMap = TkmChatCrypto.envelopeFromStreamEvent({
        'request_signature': 'sig-2',
        'message_json': envelope,
      });
      expect(fromMap?['from'], 'sender-pk');

      final direct = TkmChatCrypto.envelopeFromStreamEvent(envelope);
      expect(direct?['from'], 'sender-pk');
    });

    test('messageSignatureFromStreamEvent prefers envelope signature', () {
      expect(
        TkmChatCrypto.messageSignatureFromStreamEvent(
          {
            'request_signature': 'req-sig',
            'message_signature': 'msg-sig',
          },
          envelope: {'signature': 'envelope-sig'},
        ),
        'envelope-sig',
      );
      expect(
        TkmChatCrypto.messageSignatureFromStreamEvent({
          'request_signature': 'req-sig',
          'message_signature': 'msg-sig',
        }),
        'msg-sig',
      );
    });

    test('sentAtFromStreamEvent reads reception_timestamp', () {
      const ts = 1704067200000;
      final parsed = TkmChatCrypto.sentAtFromStreamEvent({
        'reception_timestamp': ts,
        'message_json': '{}',
      });
      expect(parsed, DateTime.fromMillisecondsSinceEpoch(ts));
    });
  });
}
