import 'dart:convert';

import 'package:takamaka_sdk_wrap/constants/chat_message_types.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_encryption.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_rsa.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';

/// High-level chat crypto orchestration (port of Java [ChatCryptoUtils]).
abstract final class TkmChatCrypto {
  static const String clientProtocolVersion = '1.1';

  /// Parent message signature for reply/reaction actions (message-actions spec).
  static final RegExp parentMessageSignaturePattern =
      RegExp(r'^[A-Za-z0-9_-]{86}\.\.$');

  /// Claimed-origin public key for attributed forward (message-actions/forward.md).
  static final RegExp forwardClaimedOriginPublicKeyPattern =
      RegExp(r'^[A-Za-z0-9_-]{43}\.$');

  /// Maximum nested [fw_content] depth (message-actions/forward.md).
  static const int maxForwardDepth = 10;

  static bool isValidParentMessageSignature(String value) =>
      parentMessageSignaturePattern.hasMatch(value);

  static bool isValidForwardClaimedOriginPublicKey(String value) =>
      forwardClaimedOriginPublicKeyPattern.hasMatch(value);
  static Future<Map<String, dynamic>> buildRegisterUserRequest({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonceResponse,
  }) async {
    final content = {
      'nonce': nonceResponse,
      'encryption_public_key': keys.rsaPublicKeyUrl64,
      'encryption_public_key_type': 'RSA_4096_ECB_OAEP_SHA256',
    };
    final signature = await TkmChatSigning.signCanonicalJson(
      keys.signKeyPair,
      content,
    );
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    return TkmChatSigning.signedEnvelope(
      from: from,
      signature: signature,
      messageType: ChatMessageTypes.registerUserSignedRequest,
      signedContentKey: 'register_user_request_signed_content',
      signedContentField: content,
    );
  }

  static Future<Map<String, dynamic>> buildRequestKeysRequest({
    required ChatKeyMaterial keys,
    required List<String> otherUserSignKeys,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final uniqueKeys = otherUserSignKeys
        .map((pk) => pk.trim())
        .where((pk) => pk.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final items = uniqueKeys
        .map((pk) => {
              'other_user_sign_key': pk,
              'timestamp': now,
            })
        .toList();
    final signature =
        await TkmChatSigning.signCanonicalJson(keys.signKeyPair, items);
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    return {
      'from': from,
      'signature': signature,
      'message_type': ChatMessageTypes.requestUserKeys,
      'signature_type': TkmChatSigning.signatureType,
      'request_user_key_request_bean_signed_content': items,
    };
  }

  /// Matches rsclient [ChatCryptoUtils.generateTopicKeyBean].
  static Map<String, dynamic> generateTopicKeyBean(String title) {
    return {
      'topic_title': title,
      'symmetric_key': TkmChatEncryption.generateSymmetricKey(),
      'conversation_salt': TkmChatEncryption.generateConversationSalt(),
    };
  }

  static Future<Map<String, dynamic>> buildCreateConversationRequest({
    required ChatKeyMaterial keys,
    required String title,
    required List<Map<String, dynamic>> memberRegisterBeans,
    Map<String, dynamic>? topicKey,
  }) async {
    final topicKeyBean = topicKey ?? generateTopicKeyBean(title);
    final symKey = topicKeyBean['symmetric_key'] as String;
    final invitations = <String, Map<String, dynamic>>{};
    for (final member in memberRegisterBeans) {
      final memberPk = member['from'] as String;
      final encPk = member['register_user_request_signed_content']
          ['encryption_public_key'] as String;
      final rsaPublic = TkmChatRsaKeyPair.decodePublicKey(encPk);
      invitations[memberPk] = {
        'enc_key_hash': TkmChatEncryption.hashSha3_256B64Url(encPk),
        'enc_key': TkmChatRsaKeyPair.encryptWithPublicKey(rsaPublic, symKey),
      };
    }
    final topicDescriptionWire = TkmChatEncryption.toWireEncMessage(
      TkmChatEncryption.encryptTopicTitle(topicKeyBean, symKey),
    );
    final topicTitle = topicKeyBean['topic_title'] as String;
    final salt = topicKeyBean['conversation_salt'] as String? ?? '';
    final signedTopic = {
      'topic_title_hash':
          TkmChatEncryption.hashSha3_256B64Url(topicTitle + salt),
      'topic_symmetric_key_signature':
          TkmChatEncryption.hashSha3_256B64Url(symKey),
      'topic_description': topicDescriptionWire,
      'topic_members_map': {
        'topic_invitation_list': invitations,
      },
    };
    final signature = await TkmChatSigning.signCanonicalJson(
      keys.signKeyPair,
      signedTopic,
    );
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    return TkmChatSigning.signedEnvelope(
      from: from,
      signature: signature,
      messageType: ChatMessageTypes.topicCreation,
      signedContentKey: 'topic',
      signedContentField: signedTopic,
    );
  }

  static Future<Map<String, dynamic>> buildBasicMessageRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String text,
    List<String> citedUsers = const [],
    List<Map<String, dynamic>> attachedMedia = const [],
  }) async {
    final mediaWire = _wireAttachedMedia(attachedMedia);
    return _buildSignedBasicMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      innerPlaintext: {
        'text_message': text,
        'attached_media': mediaWire,
      },
      citedUsers: citedUsers,
    );
  }

  /// Threaded reply — inner plaintext per message-actions/reply.md.
  static Future<Map<String, dynamic>> buildReplyMessageRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String parentMessageSignature,
    required String text,
    List<String> citedUsers = const [],
    List<Map<String, dynamic>> attachedMedia = const [],
  }) async {
    if (!isValidParentMessageSignature(parentMessageSignature)) {
      throw ArgumentError.value(
        parentMessageSignature,
        'parentMessageSignature',
        'Must match Ed25519 message signature format (86 chars + ..)',
      );
    }
    final mediaWire = _wireAttachedMedia(attachedMedia);
    final innerPlaintext = <String, dynamic>{
      'text_message': text,
      'action': 'reply',
      'targets': [parentMessageSignature],
      'client_protocol_version': clientProtocolVersion,
    };
    if (mediaWire.isNotEmpty) {
      innerPlaintext['attached_media'] = mediaWire;
    }
    return _buildSignedBasicMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      innerPlaintext: innerPlaintext,
      citedUsers: citedUsers,
    );
  }

  /// Emoji reaction — inner plaintext per message-actions/reaction.md.
  static Future<Map<String, dynamic>> buildReactionMessageRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String parentMessageSignature,
    required String emoji,
  }) async {
    if (!isValidParentMessageSignature(parentMessageSignature)) {
      throw ArgumentError.value(
        parentMessageSignature,
        'parentMessageSignature',
        'Must match Ed25519 message signature format (86 chars + ..)',
      );
    }
    final trimmed = emoji.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
          emoji, 'emoji', 'Reaction emoji must not be empty');
    }
    final preview = base64Encode(utf8.encode(trimmed));
    final innerPlaintext = {
      'attached_media': [
        {
          'media_type': 'image/png',
          'unencrypted_content_hash':
              TkmChatEncryption.hashSha3_256B64Url(preview),
          'preview': preview,
          'is_the_object': true,
        },
      ],
      'action': 'reaction',
      'targets': [parentMessageSignature],
      'client_protocol_version': clientProtocolVersion,
    };
    return _buildSignedBasicMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      innerPlaintext: innerPlaintext,
      citedUsers: const [],
    );
  }

  /// Edit own message — message-actions/edit.md.
  static Future<Map<String, dynamic>> buildEditMessageRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String parentMessageSignature,
    required String newText,
    List<Map<String, dynamic>> attachedMedia = const [],
    List<String> citedUsers = const [],
  }) async {
    if (!isValidParentMessageSignature(parentMessageSignature)) {
      throw ArgumentError.value(
        parentMessageSignature,
        'parentMessageSignature',
        'Must match Ed25519 message signature format (86 chars + ..)',
      );
    }
    final mediaWire = _wireAttachedMedia(attachedMedia);
    final innerPlaintext = <String, dynamic>{
      'text_message': newText,
      'action': 'edit',
      'targets': [parentMessageSignature],
      'client_protocol_version': clientProtocolVersion,
    };
    if (mediaWire.isNotEmpty) {
      innerPlaintext['attached_media'] = mediaWire;
    }
    return _buildSignedBasicMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      innerPlaintext: innerPlaintext,
      citedUsers: citedUsers,
    );
  }

  /// Ephemeral typing indicator — encrypted inner action relayed via retrievemessages.
  static Future<Map<String, dynamic>> buildTypingMessageRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
  }) async {
    final innerPlaintext = {
      'attached_media': <Map<String, dynamic>>[],
      'action': 'typing',
      'client_protocol_version': clientProtocolVersion,
    };
    return _buildSignedBasicMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      innerPlaintext: innerPlaintext,
      citedUsers: const [],
    );
  }

  /// Read receipt — encrypted inner action relayed via retrievemessages.
  /// [readUpToMessageSignature] is the last message the reader has seen.
  static Future<Map<String, dynamic>> buildReadReceiptMessageRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String readUpToMessageSignature,
  }) async {
    if (!isValidParentMessageSignature(readUpToMessageSignature)) {
      throw ArgumentError.value(
        readUpToMessageSignature,
        'readUpToMessageSignature',
        'Must match Ed25519 message signature format (86 chars + ..)',
      );
    }
    final innerPlaintext = {
      'attached_media': <Map<String, dynamic>>[],
      'action': 'read',
      'targets': [readUpToMessageSignature],
      'client_protocol_version': clientProtocolVersion,
    };
    return _buildSignedBasicMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      innerPlaintext: innerPlaintext,
      citedUsers: const [],
    );
  }

  /// Pin message at conversation top — message-actions/pin.md.
  static Future<Map<String, dynamic>> buildPinMessageRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String targetMessageSignature,
    String? note,
  }) async {
    if (!isValidParentMessageSignature(targetMessageSignature)) {
      throw ArgumentError.value(
        targetMessageSignature,
        'targetMessageSignature',
        'Must match Ed25519 message signature format (86 chars + ..)',
      );
    }
    final innerPlaintext = <String, dynamic>{
      'action': 'pin',
      'targets': [targetMessageSignature],
      'client_protocol_version': clientProtocolVersion,
    };
    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      innerPlaintext['text_message'] = trimmedNote;
    }
    return _buildSignedBasicMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      innerPlaintext: innerPlaintext,
      citedUsers: const [],
    );
  }

  /// Clear pinned message — message-actions/unpin.md.
  static Future<Map<String, dynamic>> buildUnpinMessageRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
  }) async {
    final innerPlaintext = {
      'action': 'unpin',
      'client_protocol_version': clientProtocolVersion,
    };
    return _buildSignedBasicMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      innerPlaintext: innerPlaintext,
      citedUsers: const [],
    );
  }

  /// Forward content into current conversation — message-actions/forward.md.
  static Future<Map<String, dynamic>> buildForwardMessageRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required Map<String, dynamic> contentToForward,
    String forwarderNote = '',
    String? claimedOriginPublicKey,
  }) async {
    if (claimedOriginPublicKey != null &&
        claimedOriginPublicKey.isNotEmpty &&
        !isValidForwardClaimedOriginPublicKey(claimedOriginPublicKey)) {
      throw ArgumentError.value(
        claimedOriginPublicKey,
        'claimedOriginPublicKey',
        'Must match Takamaka public key format (43 chars + .)',
      );
    }
    final depth = forwardDepthOfContent(contentToForward);
    if (depth > maxForwardDepth) {
      throw ArgumentError(
        'Forward depth $depth exceeds max $maxForwardDepth',
      );
    }
    final innerPlaintext = <String, dynamic>{
      'action': 'forward',
      'targets':
          claimedOriginPublicKey != null && claimedOriginPublicKey.isNotEmpty
              ? [claimedOriginPublicKey]
              : <String>[],
      'fw_content': Map<String, dynamic>.from(contentToForward),
      'client_protocol_version': clientProtocolVersion,
    };
    final trimmedNote = forwarderNote.trim();
    if (trimmedNote.isNotEmpty) {
      innerPlaintext['text_message'] = trimmedNote;
    }
    return _buildSignedBasicMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      innerPlaintext: innerPlaintext,
      citedUsers: const [],
    );
  }

  /// Share message with cryptographic provenance — message-actions/share-history.md.
  static Future<Map<String, dynamic>> buildShareHistoryMessageRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required Map<String, dynamic> originalEnvelope,
    String? relayerNote,
    bool reShared = false,
  }) async {
    final embeddedHash = conversationHashFromEnvelope(originalEnvelope);
    if (embeddedHash == null || embeddedHash != conversationHash) {
      throw ArgumentError(
        'originalEnvelope must belong to conversation $conversationHash',
      );
    }
    final signature = originalEnvelope['signature'] as String?;
    if (signature == null || !isValidParentMessageSignature(signature)) {
      throw ArgumentError('originalEnvelope missing valid signature');
    }
    final innerPlaintext = <String, dynamic>{
      'action': 'share_history',
      'original_message': Map<String, dynamic>.from(originalEnvelope),
      'client_protocol_version': clientProtocolVersion,
    };
    final trimmedNote = relayerNote?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      innerPlaintext['text_message'] = trimmedNote;
    }
    if (reShared) {
      innerPlaintext['re_shared'] = true;
    }
    return _buildSignedBasicMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      innerPlaintext: innerPlaintext,
      citedUsers: const [],
    );
  }

  /// Builds [fw_content] from decrypted inner plaintext (strips action envelope).
  static Map<String, dynamic> innerPlaintextToForwardContent(
    Map<String, dynamic> decrypted,
  ) {
    final action = decrypted['action'] as String?;
    if (action == 'forward' && decrypted['fw_content'] is Map) {
      return Map<String, dynamic>.from(decrypted['fw_content'] as Map);
    }
    final content = <String, dynamic>{};
    final text = decrypted['text_message'] as String?;
    if (text != null && text.isNotEmpty) {
      content['text_message'] = text;
    }
    final media = decrypted['attached_media'];
    if (media is List && media.isNotEmpty) {
      content['attached_media'] = [
        for (final item in media)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    }
    final nested = decrypted['fw_content'];
    if (nested is Map && nested.isNotEmpty) {
      content['fw_content'] = Map<String, dynamic>.from(nested);
    }
    return content;
  }

  /// Counts nested [fw_content] layers (1 = leaf only).
  static int forwardDepthOfContent(Map<String, dynamic> fwContent) {
    var depth = 1;
    var current = fwContent;
    while (current['fw_content'] is Map) {
      depth++;
      current = Map<String, dynamic>.from(current['fw_content'] as Map);
      if (depth > maxForwardDepth + 1) break;
    }
    return depth;
  }

  /// Creator Ed25519 public key from a `/retrieveconversation` payload.
  ///
  /// Matches `ValidationContext.conversationCreatorPk` (create request `from`).
  static String? conversationCreatorPublicKeyFromDetail(
    Map<String, dynamic> detail,
  ) {
    for (final key in [
      'create_conversation_request',
      'create_conversation_request_bean',
    ]) {
      final request = detail[key];
      if (request is Map<String, dynamic>) {
        final from = request['from'] as String?;
        if (from != null && from.trim().isNotEmpty) return from.trim();
      } else if (request is Map) {
        final from = request['from'] as String?;
        if (from != null && from.trim().isNotEmpty) return from.trim();
      }
    }
    return null;
  }

  /// Conversation hash from a signed [BasicMessageRequestBean] map.
  static String? conversationHashFromEnvelope(Map<String, dynamic> envelope) {
    final rawContent = envelope['basic_message_signed_content_bean'] ??
        envelope['basic_message_signed_content'];
    if (rawContent is! Map) return null;
    final map = Map<String, dynamic>.from(rawContent);
    return map['conversation_hash_name'] as String?;
  }

  /// `conversation_hash_name` from a `createconversation` response map.
  static String? conversationHashFromCreateResponse(
    Map<String, dynamic> response,
  ) {
    final direct = response['conversation_hash_name'];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();
    for (final key in ['response', 'create_conversation_response']) {
      final nested = response[key];
      if (nested is Map) {
        final hash = nested['conversation_hash_name'];
        if (hash is String && hash.trim().isNotEmpty) return hash.trim();
      }
    }
    return null;
  }

  /// Decrypts topic title from a [SignedContentTopicBean] map (rsclient parity).
  static String? decryptTopicTitleFromTopic({
    required Map<String, dynamic> topic,
    required String symmetricKey,
  }) {
    final encDesc = topic['topic_description'];
    if (encDesc is! Map) return null;
    try {
      final decrypted = TkmChatEncryption.decryptWithPassword(
        password: symmetricKey,
        encMessage: Map<String, dynamic>.from(encDesc),
        scope: 'TOPIC_CREATION',
      );
      final map = jsonDecode(decrypted) as Map<String, dynamic>;
      return map['topic_title'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Normalized fields from a [UserNotificationJsonBean] wire map.
  static ({
    String notificationType,
    String conversationHash,
    String senderPublicKey,
  }) parseNotificationEvent(Map<String, dynamic> event) {
    return (
      notificationType: event['notification_type'] as String? ?? '',
      conversationHash: event['conversation_hash_name'] as String? ?? '',
      senderPublicKey: event['sender_key'] as String? ?? '',
    );
  }

  /// Redact (tombstone) own message — message-actions/redact.md.
  static Future<Map<String, dynamic>> buildRedactMessageRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String parentMessageSignature,
    String? reason,
  }) async {
    if (!isValidParentMessageSignature(parentMessageSignature)) {
      throw ArgumentError.value(
        parentMessageSignature,
        'parentMessageSignature',
        'Must match Ed25519 message signature format (86 chars + ..)',
      );
    }
    final innerPlaintext = <String, dynamic>{
      'action': 'redact',
      'targets': [parentMessageSignature],
      'client_protocol_version': clientProtocolVersion,
    };
    final trimmedReason = reason?.trim();
    if (trimmedReason != null && trimmedReason.isNotEmpty) {
      innerPlaintext['text_message'] = trimmedReason;
    }
    return _buildSignedBasicMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      innerPlaintext: innerPlaintext,
      citedUsers: const [],
    );
  }

  /// Download attachment — CLIENT_API_GUIDE §5.11 (`retrieveattachment`).
  static Future<Map<String, dynamic>> buildSignedDownloadRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String uploadContentIdentifyingHash,
  }) async {
    final content = {
      'topic_title': conversationHash,
      'upload_content_id_hash': uploadContentIdentifyingHash,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    final signature =
        await TkmChatSigning.signCanonicalJson(keys.signKeyPair, content);
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    return TkmChatSigning.signedEnvelope(
      from: from,
      signature: signature,
      messageType: ChatMessageTypes.downloadRequest,
      signedContentKey: 'download_request',
      signedContentField: content,
    );
  }

  /// History fetch — CLIENT_API_GUIDE §5.7 (`retrieveallmessages`).
  static Future<Map<String, dynamic>> buildRetrieveMessageHistoryRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required int limit,
    String? afterMessageSignature,
  }) async {
    final content = <String, dynamic>{
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'number_of_messages': limit,
      'conversation_hash_name': conversationHash,
    };
    final hasCursor =
        afterMessageSignature != null && afterMessageSignature.isNotEmpty;
    if (hasCursor) {
      content['last_message_signature'] = afterMessageSignature;
    }
    final signature =
        await TkmChatSigning.signCanonicalJson(keys.signKeyPair, content);
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    return TkmChatSigning.signedEnvelope(
      from: from,
      signature: signature,
      messageType: hasCursor
          ? ChatMessageTypes.retrieveMessageBySignature
          : ChatMessageTypes.retrieveMessageLastN,
      // Java RetrieveMessageRequestBean @JsonProperty("signed_request")
      signedContentKey: 'signed_request',
      signedContentField: content,
    );
  }

  static List<Map<String, dynamic>> _wireAttachedMedia(
    List<Map<String, dynamic>> attachedMedia,
  ) {
    return attachedMedia
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) {
      final mediaType = item['media_type'] as String?;
      if (mediaType == null || mediaType.isEmpty) return false;
      if (item['is_the_object'] == true) {
        final preview = item['preview'] as String? ??
            item['base64_encoded_media'] as String?;
        return preview != null && preview.isNotEmpty;
      }
      final encHash = item['encrypted_file_hash'] as String?;
      if (encHash != null && encHash.isNotEmpty) return true;
      final legacy = item['base64_encoded_media'] as String?;
      return legacy != null && legacy.isNotEmpty;
    }).toList(growable: false);
  }

  static Future<Map<String, dynamic>> _buildSignedBasicMessageRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required Map<String, dynamic> innerPlaintext,
    List<String> citedUsers = const [],
  }) async {
    final encryptedContent = TkmChatEncryption.toWireEncMessage(
      TkmChatEncryption.encryptMessageContent(
        innerPlaintext,
        symmetricKey,
      ),
    );
    final signedContent = {
      'conversation_hash_name': conversationHash,
      'cited_users': citedUsers,
      'encrypted_content': encryptedContent,
    };
    final signature = await TkmChatSigning.signCanonicalJson(
      keys.signKeyPair,
      signedContent,
    );
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    return TkmChatSigning.signedEnvelope(
      from: from,
      signature: signature,
      messageType: ChatMessageTypes.topicMessage,
      signedContentKey: 'basic_message_signed_content_bean',
      signedContentField: signedContent,
    );
  }

  /// Parses message-action fields from decrypted inner plaintext.
  static ({
    String? action,
    List<String> targets,
    String? reactionEmoji,
    Map<String, dynamic>? fwContent,
    Map<String, dynamic>? originalMessage,
    bool reShared,
  }) parseMessageActionFields(Map<String, dynamic> decrypted) {
    final action = decrypted['action'] as String?;
    final rawTargets = decrypted['targets'];
    final targets = rawTargets is List
        ? rawTargets.whereType<String>().toList(growable: false)
        : const <String>[];
    String? reactionEmoji;
    if (action == 'reaction') {
      final media = decrypted['attached_media'];
      if (media is List && media.isNotEmpty && media.first is Map) {
        final preview = (media.first as Map)['preview'] as String?;
        if (preview != null && preview.isNotEmpty) {
          try {
            reactionEmoji = utf8.decode(base64Decode(preview));
          } catch (_) {}
        }
      }
    }
    Map<String, dynamic>? fwContent;
    final rawFw = decrypted['fw_content'];
    if (rawFw is Map) {
      fwContent = Map<String, dynamic>.from(rawFw);
    }
    Map<String, dynamic>? originalMessage;
    final rawOriginal = decrypted['original_message'];
    if (rawOriginal is Map) {
      originalMessage = Map<String, dynamic>.from(rawOriginal);
    }
    final reShared = decrypted['re_shared'] == true;
    return (
      action: action,
      targets: targets,
      reactionEmoji: reactionEmoji,
      fwContent: fwContent,
      originalMessage: originalMessage,
      reShared: reShared,
    );
  }

  static Future<Map<String, dynamic>> buildSignedTimestampRequest({
    required ChatKeyMaterial keys,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final content = {'timestamp': ts};
    final signature =
        await TkmChatSigning.signCanonicalJson(keys.signKeyPair, content);
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    return TkmChatSigning.signedEnvelope(
      from: from,
      signature: signature,
      messageType: ChatMessageTypes.signedTimestamp,
      signedContentKey: 'signed_timestamp',
      signedContentField: content,
    );
  }

  static Future<Map<String, dynamic>> buildRetrieveAllConversationsRequest({
    required ChatKeyMaterial keys,
    required int notBefore,
  }) async {
    final content = {'not_before': notBefore};
    final signature =
        await TkmChatSigning.signCanonicalJson(keys.signKeyPair, content);
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    return TkmChatSigning.signedEnvelope(
      from: from,
      signature: signature,
      messageType: ChatMessageTypes.retrieveAllConversations,
      signedContentKey: 'all_conversations',
      signedContentField: content,
    );
  }

  static Future<Map<String, dynamic>> buildRetrieveConversationRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
  }) async {
    final content = {'conversationHash': conversationHash};
    final signature =
        await TkmChatSigning.signCanonicalJson(keys.signKeyPair, content);
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    return TkmChatSigning.signedEnvelope(
      from: from,
      signature: signature,
      messageType: ChatMessageTypes.retrieveConversation,
      signedContentKey: 'conversation',
      signedContentField: content,
    );
  }

  static Future<Map<String, dynamic>> buildNotificationRequest({
    required ChatKeyMaterial keys,
    required int notBefore,
    bool onlyUnread = true,
  }) async {
    final content = {
      'not_before': notBefore,
      'only_unread': onlyUnread,
    };
    final signature =
        await TkmChatSigning.signCanonicalJson(keys.signKeyPair, content);
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    return TkmChatSigning.signedEnvelope(
      from: from,
      signature: signature,
      messageType: ChatMessageTypes.notificationRequest,
      signedContentKey: 'signed_content',
      signedContentField: content,
    );
  }

  /// FCM token register/unregister signed envelope.
  ///
  /// [deviceId] must be present in the signed content even when null — the
  /// server canonicalises Lombok beans with explicit `"device_id":null`.
  static Future<Map<String, dynamic>> buildFcmTokenRegistrationRequest({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonceResponse,
    required String fcmToken,
    required String platform,
    String? deviceId,
  }) async {
    final content = <String, dynamic>{
      'nonce': nonceResponse,
      'fcm_token': fcmToken,
      'platform': platform,
      'device_id': deviceId,
    };
    final signature =
        await TkmChatSigning.signCanonicalJson(keys.signKeyPair, content);
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    return TkmChatSigning.signedEnvelope(
      from: from,
      signature: signature,
      messageType: ChatMessageTypes.fcmTokenRegistration,
      signedContentKey: 'fcm_token_registration_signed_content',
      signedContentField: content,
    );
  }

  static String decryptSymmetricInvite({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> invite,
    TkmChatRsaKeyPair? rsaKeyPair,
  }) {
    final encrypted = _encKeyFromInvite(invite);
    return (rsaKeyPair ?? keys.rsaKeyPair).decrypt(encrypted);
  }

  /// Same as [decryptSymmetricInvite] but runs RSA off the UI isolate.
  static Future<String> decryptSymmetricInviteAsync({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> invite,
    TkmChatRsaKeyPair? rsaKeyPair,
  }) {
    final encrypted = _encKeyFromInvite(invite);
    return (rsaKeyPair ?? keys.rsaKeyPair).decryptAsync(encrypted);
  }

  static String _encKeyFromInvite(Map<String, dynamic> invite) {
    final encrypted = invite['enc_key'] ?? invite['encrypted_topic_key'];
    if (encrypted is! String || encrypted.isEmpty) {
      throw FormatException('Invite missing enc_key');
    }
    return encrypted;
  }

  /// Result of resolving the AES conversation key from a retrieveconversation payload.
  static Future<
      ({
        String? symmetricKey,
        String? error,
        TkmChatRsaKeyPair? resolvedRsaKey,
      })> resolveSymmetricKeyFromDetail({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> detail,
  }) async {
    if (detail.isEmpty) {
      return (
        symmetricKey: null,
        error: 'empty retrieveConversation response',
        resolvedRsaKey: null,
      );
    }
    final topic = topicFromRetrieveConversationResponse(detail);
    if (topic == null) {
      return (
        symmetricKey: null,
        error: 'topic missing in response keys=${detail.keys.toList()}',
        resolvedRsaKey: null,
      );
    }
    return symmetricKeyFromTopic(keys: keys, topic: topic);
  }

  /// Decrypts the caller's invite from a [SignedContentTopicBean] map.
  static Future<
      ({
        String? symmetricKey,
        String? error,
        TkmChatRsaKeyPair? resolvedRsaKey,
      })> symmetricKeyFromTopic({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> topic,
  }) async {
    final invitations = invitationListFromTopic(topic);
    if (invitations == null || invitations.isEmpty) {
      return (
        symmetricKey: null,
        error: 'topic_invitation_list missing or empty',
        resolvedRsaKey: null,
      );
    }

    final mySignPk = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    final candidates = <Map<String, dynamic>>[];

    void addCandidate(Map<String, dynamic>? invite) {
      if (invite == null) return;
      for (final existing in candidates) {
        if (identical(existing, invite)) return;
        if (existing['enc_key'] == invite['enc_key'] &&
            existing['enc_key_hash'] == invite['enc_key_hash']) {
          return;
        }
      }
      candidates.add(invite);
    }

    addCandidate(_inviteMap(invitations[mySignPk]));
    for (final rsa in keys.rsaKeyCandidates) {
      addCandidate(
        _inviteByEncKeyHashFallback(invitations, rsa.publicKeyUrl64),
      );
    }
    addCandidate(_singleInviteFallback(invitations));
    for (final invite in invitations.values) {
      addCandidate(_inviteMap(invite));
    }

    if (candidates.isEmpty) {
      return (
        symmetricKey: null,
        error: 'no invite for $mySignPk among ${invitations.length} member(s)',
        resolvedRsaKey: null,
      );
    }

    final rsaCandidates = _orderedRsaCandidatesForInvites(
      keys: keys,
      invites: candidates,
    );

    String? lastError;
    for (final invite in candidates) {
      final encKeyHash = invite['enc_key_hash'] as String?;
      final matchingRsa = encKeyHash == null
          ? rsaCandidates
          : rsaCandidates
              .where(
                (rsa) =>
                    TkmChatEncryption.hashSha3_256B64Url(rsa.publicKeyUrl64) ==
                    encKeyHash,
              )
              .toList();
      final rsaOrder =
          matchingRsa.isNotEmpty ? matchingRsa : rsaCandidates;

      for (final rsa in rsaOrder) {
        try {
          final symKey = await decryptSymmetricInviteAsync(
            keys: keys,
            invite: invite,
            rsaKeyPair: rsa,
          );
          if (symKey.isNotEmpty) {
            return (
              symmetricKey: symKey,
              error: null,
              resolvedRsaKey:
                  rsa.publicKeyUrl64 == keys.rsaPublicKeyUrl64 ? null : rsa,
            );
          }
          lastError = 'decryptSymmetricInvite returned empty';
        } catch (e) {
          lastError = e.toString();
        }
      }
    }
    return (
      symmetricKey: null,
      error: 'RSA invite decrypt failed: $lastError '
          '(tried ${rsaCandidates.length} RSA key(s), ${candidates.length} invite(s))',
      resolvedRsaKey: null,
    );
  }

  static List<TkmChatRsaKeyPair> _orderedRsaCandidatesForInvites({
    required ChatKeyMaterial keys,
    required List<Map<String, dynamic>> invites,
  }) {
    final hashes = <String>{
      for (final invite in invites)
        if (invite['enc_key_hash'] is String) invite['enc_key_hash'] as String,
    };
    if (hashes.isEmpty) {
      return keys.rsaKeyCandidates;
    }
    final matched = <TkmChatRsaKeyPair>[];
    final rest = <TkmChatRsaKeyPair>[];
    for (final rsa in keys.rsaKeyCandidates) {
      final hash = TkmChatEncryption.hashSha3_256B64Url(rsa.publicKeyUrl64);
      if (hashes.contains(hash)) {
        matched.add(rsa);
      } else {
        rest.add(rsa);
      }
    }
    return [...matched, ...rest];
  }

  /// Extracts `topic_invitation_list` from a topic map (tolerates wire variants).
  static Map<String, dynamic>? invitationListFromTopic(
    Map<String, dynamic> topic,
  ) {
    final members = topic['topic_members_map'];
    if (members is! Map) return null;
    final membersMap = Map<String, dynamic>.from(members);

    final nested = membersMap['topic_invitation_list'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }

    if (membersMap.values.every(_looksLikeInviteEntry)) {
      return membersMap;
    }
    return null;
  }

  static Map<String, dynamic>? _inviteMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static Map<String, dynamic>? _singleInviteFallback(
    Map<String, dynamic> invitations,
  ) {
    if (invitations.length != 1) return null;
    return _inviteMap(invitations.values.first);
  }

  static Map<String, dynamic>? _inviteByEncKeyHashFallback(
    Map<String, dynamic> invitations,
    String rsaPublicKeyUrl64,
  ) {
    final myEncHash = TkmChatEncryption.hashSha3_256B64Url(rsaPublicKeyUrl64);
    for (final entry in invitations.entries) {
      final invite = _inviteMap(entry.value);
      if (invite == null) continue;
      if (invite['enc_key_hash'] == myEncHash) {
        return invite;
      }
    }
    return null;
  }

  static bool _looksLikeInviteEntry(Object? value) {
    if (value is! Map) return false;
    return value.containsKey('enc_key') ||
        value.containsKey('encrypted_topic_key');
  }

  /// Decrypted payload from a live/history [BasicMessageRequestBean] JSON map.
  static Map<String, dynamic>? decryptContentFromMessageEnvelope({
    required Map<String, dynamic> envelope,
    required String symmetricKey,
    String? filterConversationHash,
  }) {
    final rawContent = envelope['basic_message_signed_content_bean'] ??
        envelope['basic_message_signed_content'];
    if (rawContent is! Map) return null;
    final content = Map<String, dynamic>.from(rawContent);
    final hash = content['conversation_hash_name'] as String?;
    if (filterConversationHash != null && hash != filterConversationHash) {
      return null;
    }
    final enc = content['encrypted_content'];
    if (enc is! Map) return null;
    try {
      return TkmChatEncryption.decryptMessageContent(
        Map<String, dynamic>.from(enc),
        symmetricKey,
      );
    } catch (_) {
      return null;
    }
  }

  /// Decrypts plaintext from a live/history [BasicMessageRequestBean] JSON map.
  static String? decryptTextFromMessageEnvelope({
    required Map<String, dynamic> envelope,
    required String symmetricKey,
    String? filterConversationHash,
  }) {
    final decrypted = decryptContentFromMessageEnvelope(
      envelope: envelope,
      symmetricKey: symmetricKey,
      filterConversationHash: filterConversationHash,
    );
    if (decrypted == null) return null;
    return formatMessageDisplayText(decrypted);
  }

  /// Human-readable line for UI from decrypted message content.
  static String formatMessageDisplayText(Map<String, dynamic> decrypted) {
    final text = (decrypted['text_message'] as String?)?.trim() ?? '';
    final media = decrypted['attached_media'];
    if (media is! List || media.isEmpty) {
      return text;
    }

    final labels = <String>[];
    for (final item in media) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final label = _mediaDisplayLabel(map);
      if (label.isNotEmpty) labels.add(label);
    }

    if (labels.isEmpty) return text;
    if (text.isEmpty) return labels.join('\n');
    return '$text\n${labels.join('\n')}';
  }

  static String _mediaDisplayLabel(Map<String, dynamic> media) {
    final type = (media['media_type'] as String?)?.toLowerCase() ?? '';
    if (type.startsWith('image/')) return 'Photo';
    if (type.startsWith('audio/')) return 'Audio';
    if (type.contains('contact')) return 'Contact';
    if (type.contains('location')) return 'Location';
    if (type.startsWith('application/') || type.startsWith('text/')) {
      return 'Document';
    }
    return 'Attachment';
  }

  /// Parses envelope JSON from [RetrieveMessagesResponseBean.message_json].
  static Map<String, dynamic>? messageEnvelopeFromJson(String messageJson) {
    try {
      final decoded = jsonDecode(messageJson);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Resolves [SignedContentTopicBean] from a `/retrieveconversation` JSON map.
  ///
  /// Server payloads vary: nested under `topic`, inside
  /// `create_conversation_request.topic`, or as a bare topic object.
  static Map<String, dynamic>? topicFromRetrieveConversationResponse(
    Map<String, dynamic> detail,
  ) {
    for (final key in ['topic', 'signed_content_topic', 'signed_content']) {
      final direct = detail[key];
      if (direct is Map<String, dynamic>) return direct;
      if (direct is Map) return Map<String, dynamic>.from(direct);
    }

    for (final requestKey in [
      'create_conversation_request',
      'create_conversation_request_bean',
    ]) {
      final request = detail[requestKey];
      if (request is Map) {
        final requestMap = Map<String, dynamic>.from(request);
        final nested = requestMap['topic'];
        if (nested is Map<String, dynamic>) return nested;
        if (nested is Map) return Map<String, dynamic>.from(nested);
        if (requestMap.containsKey('topic_members_map') ||
            requestMap.containsKey('topic_description')) {
          return requestMap;
        }
      }
    }

    if (detail.containsKey('topic_members_map') ||
        detail.containsKey('topic_description')) {
      return Map<String, dynamic>.from(detail);
    }
    return null;
  }

  /// Parses a live/history stream item into a [BasicMessageRequestBean] map.
  static Map<String, dynamic>? envelopeFromStreamEvent(
    Map<String, dynamic> event,
  ) {
    final raw = event['message_json'] ?? event['messageJson'];
    if (raw is String && raw.isNotEmpty) {
      return messageEnvelopeFromJson(raw);
    }
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);

    if (event.containsKey('basic_message_signed_content_bean') ||
        event.containsKey('basic_message_signed_content')) {
      return Map<String, dynamic>.from(event);
    }
    return null;
  }

  /// Stable message id from a stream item.
  ///
  /// Prefer the signed envelope [signature] (canonical TOPIC_MESSAGE id). Outer
  /// [request_signature] on history wrappers can repeat across unrelated items.
  static String? messageSignatureFromStreamEvent(
    Map<String, dynamic> event, {
    Map<String, dynamic>? envelope,
  }) {
    final fromEnvelope = envelope?['signature'];
    if (fromEnvelope is String && fromEnvelope.isNotEmpty) {
      return fromEnvelope;
    }
    for (final key in [
      'message_signature',
      'messageSignature',
      'request_signature',
      'requestSignature',
    ]) {
      final value = event[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  /// Server-side reception time from [RetrieveMessagesResponseBean].
  static DateTime? sentAtFromStreamEvent(Map<String, dynamic> event) {
    for (final key in ['reception_timestamp', 'receptionTimestamp']) {
      final value = event[key];
      if (value is int && value > 0) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is num && value > 0) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
    }
    return null;
  }
}
