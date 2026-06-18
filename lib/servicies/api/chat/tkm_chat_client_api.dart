import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:takamaka_sdk_wrap/constants/chat_message_types.dart';
import 'package:takamaka_sdk_wrap/constants/chat_server_endpoints.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_attachment.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_crypto.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_chat_enums_api.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';
import 'package:takamaka_sdk_wrap/models/chat/stream_encrypted_descriptor.dart';
import 'package:takamaka_sdk_wrap/models/chat/upload_status_bean.dart';
import 'package:takamaka_sdk_wrap/servicies/api/chat/tkm_rsocket_client.dart';

typedef ChatTransportReconnectHandler = Future<void> Function();

/// rschat API facade (RSocket routes from [ChatServerEndpoints]).
class TkmChatClientApi {
  TkmChatClientApi({required TkmChatEnumEnvironments environment})
      : _client = TkmRsChatClient(wsUrl: environment.wsUrl);

  final TkmRsChatClient _client;

  /// Called after the WebSocket is reopened so the server session is restored.
  ChatTransportReconnectHandler? onTransportReconnect;

  bool get isTransportConnected => _client.isConnected;

  Future<void> forceReconnectTransport() => _client.forceReconnect();

  /// Re-registers the user on a fresh transport (fresh nonce + registeruser).
  Future<Map<String, dynamic>> reregisterUser({
    required ChatKeyMaterial keys,
  }) async {
    final nonce = await _client.requestResponse(ChatServerEndpoints.nonce);
    final request = await TkmChatCrypto.buildRegisterUserRequest(
      keys: keys,
      nonceResponse: nonce ?? {},
    );
    await _client.requestResponse(
      ChatServerEndpoints.registerUser,
      request,
    );
    return request;
  }

  Future<Map<String, dynamic>?> _requestResponse(
    String route, [
    Object? data,
  ]) async {
    try {
      return await _client.requestResponse(route, data);
    } catch (e) {
      if (!TkmRsChatClient.isTransportError(e)) rethrow;
      await _restoreTransport();
      return _client.requestResponse(route, data);
    }
  }

  Future<void> _restoreTransport() async {
    await _client.forceReconnect();
    if (onTransportReconnect != null) {
      await onTransportReconnect!();
    }
  }

  Future<Map<String, dynamic>> getNonce() async {
    final response = await _requestResponse(ChatServerEndpoints.nonce);
    return response ?? {};
  }

  Future<Map<String, dynamic>> registerUser({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonce,
  }) async {
    final request = await TkmChatCrypto.buildRegisterUserRequest(
      keys: keys,
      nonceResponse: nonce,
    );
    return registerUserWithRequest(request);
  }

  /// Sends a pre-built [RegisterUserRequestBean] JSON map.
  Future<Map<String, dynamic>> registerUserWithRequest(
    Map<String, dynamic> request,
  ) async {
    final response = await _requestResponse(
      ChatServerEndpoints.registerUser,
      request,
    );
    return response ?? {};
  }

  Stream<Map<String, dynamic>> requestKeys({
    required ChatKeyMaterial keys,
    required List<String> otherPublicKeys,
  }) async* {
    final request = await TkmChatCrypto.buildRequestKeysRequest(
      keys: keys,
      otherUserSignKeys: otherPublicKeys,
    );
    yield* _client.requestStream(ChatServerEndpoints.requestKeys, request);
  }

  Future<({Map<String, dynamic> response, String symmetricKey})>
      createConversation({
    required ChatKeyMaterial keys,
    required String title,
    required List<Map<String, dynamic>> members,
  }) async {
    final topicKey = TkmChatCrypto.generateTopicKeyBean(title);
    final symmetricKey = topicKey['symmetric_key'] as String;
    final request = await TkmChatCrypto.buildCreateConversationRequest(
      keys: keys,
      title: title,
      memberRegisterBeans: members,
      topicKey: topicKey,
    );
    final response = await _requestResponse(
      ChatServerEndpoints.createConversation,
      request,
    );
    return (response: response ?? {}, symmetricKey: symmetricKey);
  }

  Future<Map<String, dynamic>> sendMessage({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String text,
    List<String> citedUsers = const [],
    List<Map<String, dynamic>> attachedMedia = const [],
    String? replyToParentSignature,
  }) async {
    final request = replyToParentSignature != null &&
            replyToParentSignature.isNotEmpty &&
            TkmChatCrypto.isValidParentMessageSignature(replyToParentSignature)
        ? await TkmChatCrypto.buildReplyMessageRequest(
            keys: keys,
            conversationHash: conversationHash,
            symmetricKey: symmetricKey,
            parentMessageSignature: replyToParentSignature,
            text: text,
            citedUsers: citedUsers,
            attachedMedia: attachedMedia,
          )
        : await TkmChatCrypto.buildBasicMessageRequest(
            keys: keys,
            conversationHash: conversationHash,
            symmetricKey: symmetricKey,
            text: text,
            citedUsers: citedUsers,
            attachedMedia: attachedMedia,
          );
    final response = await _requestResponse(
      ChatServerEndpoints.messages,
      request,
    );
    return response ?? {};
  }

  Future<Map<String, dynamic>> sendTyping({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
  }) async {
    final request = await TkmChatCrypto.buildTypingMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
    );
    final response = await _requestResponse(
      ChatServerEndpoints.messages,
      request,
    );
    return response ?? {};
  }

  Future<Map<String, dynamic>> sendReadReceipt({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String readUpToMessageSignature,
  }) async {
    final request = await TkmChatCrypto.buildReadReceiptMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      readUpToMessageSignature: readUpToMessageSignature,
    );
    final response = await _requestResponse(
      ChatServerEndpoints.messages,
      request,
    );
    return response ?? {};
  }

  Future<Map<String, dynamic>> sendReaction({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String parentMessageSignature,
    required String emoji,
  }) async {
    final request = await TkmChatCrypto.buildReactionMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      parentMessageSignature: parentMessageSignature,
      emoji: emoji,
    );
    final response = await _requestResponse(
      ChatServerEndpoints.messages,
      request,
    );
    return response ?? {};
  }

  Future<Map<String, dynamic>> editMessage({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String parentMessageSignature,
    required String newText,
  }) async {
    final request = await TkmChatCrypto.buildEditMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      parentMessageSignature: parentMessageSignature,
      newText: newText,
    );
    final response = await _requestResponse(
      ChatServerEndpoints.messages,
      request,
    );
    return response ?? {};
  }

  Future<Map<String, dynamic>> redactMessage({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String parentMessageSignature,
    String? reason,
  }) async {
    final request = await TkmChatCrypto.buildRedactMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      parentMessageSignature: parentMessageSignature,
      reason: reason,
    );
    final response = await _requestResponse(
      ChatServerEndpoints.messages,
      request,
    );
    return response ?? {};
  }

  Future<Map<String, dynamic>> pinMessage({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String targetMessageSignature,
    String? note,
  }) async {
    final request = await TkmChatCrypto.buildPinMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      targetMessageSignature: targetMessageSignature,
      note: note,
    );
    final response = await _requestResponse(
      ChatServerEndpoints.messages,
      request,
    );
    return response ?? {};
  }

  Future<Map<String, dynamic>> unpinMessage({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
  }) async {
    final request = await TkmChatCrypto.buildUnpinMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
    );
    final response = await _requestResponse(
      ChatServerEndpoints.messages,
      request,
    );
    return response ?? {};
  }

  Future<Map<String, dynamic>> forwardMessage({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required Map<String, dynamic> contentToForward,
    String forwarderNote = '',
    String? claimedOriginPublicKey,
  }) async {
    final request = await TkmChatCrypto.buildForwardMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      contentToForward: contentToForward,
      forwarderNote: forwarderNote,
      claimedOriginPublicKey: claimedOriginPublicKey,
    );
    final response = await _requestResponse(
      ChatServerEndpoints.messages,
      request,
    );
    return response ?? {};
  }

  Future<Map<String, dynamic>> shareHistoryMessage({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required Map<String, dynamic> originalEnvelope,
    String? relayerNote,
    bool reShared = false,
  }) async {
    final request = await TkmChatCrypto.buildShareHistoryMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      originalEnvelope: originalEnvelope,
      relayerNote: relayerNote,
      reShared: reShared,
    );
    final response = await _requestResponse(
      ChatServerEndpoints.messages,
      request,
    );
    return response ?? {};
  }

  /// Encrypted attachment bytes from server (client must decrypt with symKey + SED).
  Stream<Uint8List> retrieveAttachment({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String uploadContentIdentifyingHash,
  }) async* {
    final request = await TkmChatCrypto.buildSignedDownloadRequest(
      keys: keys,
      conversationHash: conversationHash,
      uploadContentIdentifyingHash: uploadContentIdentifyingHash,
    );
    yield* _client.requestStreamBytes(
      ChatServerEndpoints.retrieveAttachment,
      request,
    );
  }

  /// Uploads encrypted attachment bytes via RSocket request-channel.
  Future<UploadStatusBean> submitAttachmentStreaming({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required EncryptedAttachmentResult encrypted,
    int chunkSize = kChatAttachmentUploadChunkSize,
    void Function(double progress)? onUploadProgress,
  }) async {
    final signedRequest = await TkmChatAttachment.buildSignedUploadRequest(
      keys: keys,
      conversationHash: conversationHash,
      encrypted: encrypted,
    );
    final signedRequestJson = jsonEncode(signedRequest);
    final controller = StreamController<Uint8List>();
    unawaited(_emitUploadChunks(
      controller,
      encrypted.encryptedData,
      chunkSize,
    ));

    UploadStatusBean? lastStatus;
    final totalBytes = encrypted.encryptedData.length;
    try {
      await for (final statusJson in _client
          .requestChannelForUploadJson(
            ChatServerEndpoints.submitAttachment,
            controller.stream,
            signedRequestJson,
          )
          .timeout(const Duration(minutes: 5))) {
        final status = UploadStatusBean.fromJson(statusJson);
        lastStatus = status;
        if (onUploadProgress != null && totalBytes > 0) {
          final uploadedChunk = status.uploadedChunk ?? 0;
          var uploadedBytes = uploadedChunk * chunkSize;
          if (uploadedBytes > totalBytes) uploadedBytes = totalBytes;
          if (status.isComplete) {
            onUploadProgress(1.0);
          } else {
            onUploadProgress(uploadedBytes / totalBytes);
          }
        }
        if (status.isError) {
          throw StateError('Upload failed: ${status.error ?? status.status}');
        }
        if (status.isComplete) break;
      }
    } on TimeoutException {
      throw StateError('Attachment upload timed out');
    } on Exception catch (e) {
      final message = '$e';
      if (message == 'Exception: Unsupported') {
        throw StateError(
          'Attachment upload is unavailable: RSocket requestChannel is not supported',
        );
      }
      if (message.contains('RS-515') ||
          message.contains('exceeds the number requested')) {
        throw StateError(
          'Attachment upload failed: server rejected chunk flow (REQUEST_N). '
          'Retry after app restart.',
        );
      }
      rethrow;
    }
    return lastStatus ?? const UploadStatusBean(status: 'UNKNOWN');
  }

  /// Downloads encrypted bytes and decrypts with conversation symmetric key + SED.
  Future<Uint8List> downloadAndDecryptAttachment({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String uploadContentIdentifyingHash,
    required StreamEncryptedDescriptor descriptor,
    String? expectedPlaintextHashHex,
  }) async {
    final encryptedChunks = <int>[];
    await for (final chunk in retrieveAttachment(
      keys: keys,
      conversationHash: conversationHash,
      uploadContentIdentifyingHash: uploadContentIdentifyingHash,
    )) {
      encryptedChunks.addAll(chunk);
    }
    return TkmChatAttachment.decryptDownload(
      symmetricKey: symmetricKey,
      descriptor: descriptor,
      encryptedData: Uint8List.fromList(encryptedChunks),
      expectedPlaintextHashHex: expectedPlaintextHashHex,
    );
  }

  Future<void> _emitUploadChunks(
    StreamController<Uint8List> controller,
    Uint8List data,
    int chunkSize,
  ) async {
    try {
      var offset = 0;
      while (offset < data.length) {
        final end = (offset + chunkSize).clamp(0, data.length);
        controller.add(Uint8List.fromList(data.sublist(offset, end)));
        offset = end;
        await Future<void>.delayed(Duration.zero);
      }
      await controller.close();
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
        await controller.close();
      }
    }
  }

  Stream<Map<String, dynamic>> retrieveMessageHistory({
    required ChatKeyMaterial keys,
    required String conversationHash,
    int limit = 50,
    String? afterMessageSignature,
  }) async* {
    final request = await TkmChatCrypto.buildRetrieveMessageHistoryRequest(
      keys: keys,
      conversationHash: conversationHash,
      limit: limit,
      afterMessageSignature: afterMessageSignature,
    );
    final signed = request['signed_request'] as Map<String, dynamic>?;
    debugPrint(
      'chat[rschat] retrieveallmessages REQUEST '
      'route=${ChatServerEndpoints.retrieveAllMessages} '
      'message_type=${request['message_type']} '
      'conversation_hash=${signed?['conversation_hash_name']} '
      'limit=${signed?['number_of_messages']} '
      'cursor=${signed?['last_message_signature'] ?? "null"}',
    );
    var itemIndex = 0;
    try {
      await for (final event in _client.requestStream(
        ChatServerEndpoints.retrieveAllMessages,
        request,
      )) {
        itemIndex++;
        final msgJson = event['message_json'] ?? event['messageJson'];
        final msgJsonLen = msgJson is String ? msgJson.length : 0;
        debugPrint(
          'chat[rschat] retrieveallmessages RESPONSE #$itemIndex '
          'keys=${event.keys.toList()} '
          'request_signature=${event['request_signature'] ?? event['message_signature']} '
          'message_json_len=$msgJsonLen',
        );
        yield event;
      }
      debugPrint(
        'chat[rschat] retrieveallmessages STREAM_END '
        'conversation_hash=$conversationHash items=$itemIndex',
      );
    } catch (e, st) {
      debugPrint(
        'chat[rschat] retrieveallmessages ERROR '
        'conversation_hash=$conversationHash items=$itemIndex error=$e',
      );
      debugPrint('chat[rschat] retrieveallmessages stack: $st');
      rethrow;
    }
  }

  Stream<Map<String, dynamic>> subscribeMessages({
    required ChatKeyMaterial keys,
  }) async* {
    final request = await TkmChatCrypto.buildSignedTimestampRequest(keys: keys);
    yield* _client.requestStream(
      ChatServerEndpoints.retrieveMessages,
      request,
    );
  }

  Stream<String> retrieveAllConversations({
    required ChatKeyMaterial keys,
    required int notBefore,
  }) async* {
    final request = await TkmChatCrypto.buildRetrieveAllConversationsRequest(
      keys: keys,
      notBefore: notBefore,
    );
    await for (final item in _client.requestStream(
      ChatServerEndpoints.retrieveAllConversations,
      request,
    )) {
      if (item.containsKey('value')) {
        yield item['value'].toString();
      } else if (item.containsKey('conversation_hash_name')) {
        yield item['conversation_hash_name'] as String;
      } else {
        yield item.toString();
      }
    }
  }

  Future<Map<String, dynamic>> retrieveConversation({
    required ChatKeyMaterial keys,
    required String conversationHash,
  }) async {
    final request = await TkmChatCrypto.buildRetrieveConversationRequest(
      keys: keys,
      conversationHash: conversationHash,
    );
    debugPrint(
      'chat[rschat] retrieveconversation REQUEST '
      'route=${ChatServerEndpoints.retrieveConversation} '
      'conversation_hash=$conversationHash',
    );
    try {
      final response = await _requestResponse(
        ChatServerEndpoints.retrieveConversation,
        request,
      );
      final map = response ?? {};
      debugPrint(
        'chat[rschat] retrieveconversation RESPONSE '
        'conversation_hash=$conversationHash '
        'keys=${map.keys.toList()} '
        'hasTopic=${TkmChatCrypto.topicFromRetrieveConversationResponse(map) != null}',
      );
      return map;
    } catch (e, st) {
      debugPrint(
        'chat[rschat] retrieveconversation ERROR '
        'conversation_hash=$conversationHash error=$e',
      );
      debugPrint('chat[rschat] retrieveconversation stack: $st');
      rethrow;
    }
  }

  Stream<Map<String, dynamic>> subscribeNotifications({
    required ChatKeyMaterial keys,
    required int notBefore,
    bool onlyUnread = true,
  }) async* {
    final request = await TkmChatCrypto.buildNotificationRequest(
      keys: keys,
      notBefore: notBefore,
      onlyUnread: onlyUnread,
    );
    yield* _client.requestStream(ChatServerEndpoints.notification, request);
  }

  /// Buffered notification history — rsclient [DefaultCalls.getNotificationHistory].
  Stream<Map<String, dynamic>> retrieveNotificationHistory({
    required ChatKeyMaterial keys,
    required int notBefore,
    bool onlyUnread = true,
  }) async* {
    final request = await TkmChatCrypto.buildNotificationRequest(
      keys: keys,
      notBefore: notBefore,
      onlyUnread: onlyUnread,
    );
    yield* _client.requestStream(
      ChatServerEndpoints.notificationHistory,
      request,
    );
  }

  Future<Map<String, dynamic>> registerFcmToken({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonce,
    required String fcmToken,
    required String platform,
    String? deviceId,
  }) async {
    final content = {
      'nonce': nonce,
      'fcm_token': fcmToken,
      'platform': platform,
      if (deviceId != null) 'device_id': deviceId,
    };
    final signature =
        await TkmChatSigning.signCanonicalJson(keys.signKeyPair, content);
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    final request = {
      'from': from,
      'signature': signature,
      'message_type': 'FCM_TOKEN_REGISTRATION',
      'signature_type': TkmChatSigning.signatureType,
      'fcm_token_registration_signed_content': content,
    };
    final response = await _requestResponse(
      ChatServerEndpoints.registerFcmToken,
      request,
    );
    return response ?? {};
  }

  Future<void> disconnect() => _client.disconnect();
}
