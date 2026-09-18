import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:takamaka_sdk_wrap/constants/chat_server_endpoints.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_attachment.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_crypto.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_manifest_limits.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_profile_requests.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_chat_enums_api.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';
import 'package:takamaka_sdk_wrap/models/chat/stream_encrypted_descriptor.dart';
import 'package:takamaka_sdk_wrap/models/chat/tkm_chat_profile_models.dart';
import 'package:takamaka_sdk_wrap/models/chat/tkm_delete_message_response.dart';
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

  Map<String, dynamic>? _lastServerInfo;
  TkmChatNegotiatedTransport? _negotiatedTransport;

  /// Last `serverinfo` JSON, or null if never probed / the probe failed.
  Map<String, dynamic>? get lastServerInfo => _lastServerInfo;

  TkmChatNegotiatedTransport? get negotiatedTransport => _negotiatedTransport;

  int get negotiatedUploadChunkBytes =>
      _negotiatedTransport?.uploadChunkBytes ??
      TkmChatManifestLimits.resolve(
        0,
        TkmChatManifestLimits.mobileUploadTargetBytes,
      ).uploadChunkBytes;

  bool isKnownUnsupported(String route) =>
      _negotiatedTransport?.isKnownUnsupported(route) ?? false;

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

  /// Unsigned `serverinfo` probe (DR-022). Empty map if the server omits it.
  Future<Map<String, dynamic>> getServerInfo() async {
    final response = await _requestResponse(ChatServerEndpoints.serverInfo);
    return response ?? {};
  }

  /// Probe `serverinfo` and size the attachment upload chunk (DR-022/023).
  Future<TkmChatNegotiatedTransport?> negotiateTransport({
    int uploadTargetBytes = TkmChatManifestLimits.mobileUploadTargetBytes,
  }) async {
    try {
      final info = await getServerInfo();
      _lastServerInfo = info;
      final advertised = (info['maxFramePayloadLength'] as num?)?.toInt() ?? 0;
      final resolution =
          TkmChatManifestLimits.resolve(advertised, uploadTargetBytes);
      final routes = info['supportedRoutes'];
      _negotiatedTransport = TkmChatNegotiatedTransport(
        resolution: resolution,
        manifestVersion: info['manifestVersion'] as String? ?? '1.0',
        serverVersion: info['serverVersion'] as String? ?? '',
        clientDecoderMaxBytes: TkmChatManifestLimits.clientOwnMaxFrameBytes,
        editDeleteWindowMs: (info['editDeleteWindowMs'] as num?)?.toInt() ?? 0,
        maxAttachmentSizeBytes:
            (info['maxAttachmentSizeBytes'] as num?)?.toInt() ?? 0,
        supportedRoutes: routes is List
            ? routes.whereType<String>().toList(growable: false)
            : const <String>[],
      );
      return _negotiatedTransport;
    } catch (e) {
      debugPrint('serverinfo probe failed: $e');
      _negotiatedTransport = null;
      _lastServerInfo = null;
      return null;
    }
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

  /// Plain fire-and-forget typing emit (`typingemit`). Must follow a live
  /// [subscribeTyping] on the same connection or the server drops the frame.
  Future<void> emitTyping({
    required String conversationHash,
  }) {
    return _client.fireAndForget(
      ChatServerEndpoints.typingEmit,
      TkmChatCrypto.buildTypingEmitPayload(conversationHash: conversationHash),
    );
  }

  /// Signed request-stream `typingsubscribe`.
  Stream<Map<String, dynamic>> subscribeTyping({
    required ChatKeyMaterial keys,
  }) async* {
    final request = await TkmChatCrypto.buildTypingSubscribeRequest(keys: keys);
    yield* _client.requestStream(
      ChatServerEndpoints.typingSubscribe,
      request,
    );
  }

  /// Signed request-response `submitreadreceipt` (does **not** use `messages`).
  Future<Map<String, dynamic>> submitReadReceipt({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String symmetricKey,
    required String lastReadMessageSignature,
  }) async {
    final request = await TkmChatCrypto.buildReadReceiptRequest(
      keys: keys,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      lastReadMessageSignature: lastReadMessageSignature,
    );
    final response = await _requestResponse(
      ChatServerEndpoints.submitReadReceipt,
      request,
    );
    return response ?? {};
  }

  /// Signed request-stream `retrievereadreceipts`. Always pass a **fresh**
  /// [nonce] from [getNonce] (single-use on subscribe).
  Stream<Map<String, dynamic>> retrieveReadReceipts({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonce,
    int? notBefore,
  }) async* {
    final request = await TkmChatCrypto.buildRetrieveReadReceiptsRequest(
      keys: keys,
      nonceResponse: nonce,
      notBefore: notBefore,
    );
    yield* _client.requestStream(
      ChatServerEndpoints.retrieveReadReceipts,
      request,
    );
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

  /// DR-025 "delete for everyone" (`deletemessage`).
  Future<TkmDeleteMessageResponse> deleteMessage({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required String targetMessageSignature,
    List<String>? targetEncryptedFileHashes,
    Map<String, dynamic>? encryptedReason,
  }) async {
    final request = await TkmChatCrypto.buildDeleteMessageRequest(
      keys: keys,
      conversationHash: conversationHash,
      targetMessageSignature: targetMessageSignature,
      targetEncryptedFileHashes: targetEncryptedFileHashes,
      encryptedReason: encryptedReason,
    );
    final response = await _requestResponse(
      ChatServerEndpoints.deleteMessage,
      request,
    );
    return TkmDeleteMessageResponse.fromJson(response ?? const {});
  }

  /// DR-025 deletion-log catch-up (`retrievedeletions`).
  Stream<Map<String, dynamic>> retrieveDeletions({
    required ChatKeyMaterial keys,
    required String conversationHash,
    int? since,
  }) async* {
    final request = await TkmChatCrypto.buildRetrieveDeletionsRequest(
      keys: keys,
      conversationHash: conversationHash,
      since: since,
    );
    yield* _client.requestStream(
      ChatServerEndpoints.retrieveDeletions,
      request,
    );
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
  ///
  /// [onUploadProgress] reflects **server ACK** progress only (not local queue
  /// emission). Values stay in `0..0.99` — callers should reserve `1.0` for
  /// post-upload work (cache / send message) completion.
  Future<UploadStatusBean> submitAttachmentStreaming({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required EncryptedAttachmentResult encrypted,
    int? chunkSize,
    void Function(double progress)? onUploadProgress,
  }) async {
    final effectiveChunk = chunkSize ?? negotiatedUploadChunkBytes;
    final signedRequest = await TkmChatAttachment.buildSignedUploadRequest(
      keys: keys,
      conversationHash: conversationHash,
      encrypted: encrypted,
    );
    final signedRequestJson = jsonEncode(signedRequest);
    final controller = StreamController<Uint8List>();
    final totalBytes = encrypted.encryptedData.length;
    var bestProgress = 0.0;

    void reportProgress(double value) {
      final clamped = value.clamp(0.0, 0.99);
      if (clamped < bestProgress) return;
      bestProgress = clamped;
      onUploadProgress?.call(bestProgress);
    }

    unawaited(_emitUploadChunks(
      controller,
      encrypted.encryptedData,
      effectiveChunk,
    ));

    UploadStatusBean? lastStatus;
    try {
      // Idle timeout between status ACKs (resets on each event); overall cap 5 min.
      final responseStream = _client
          .requestChannelForUploadJson(
        ChatServerEndpoints.submitAttachment,
        controller.stream,
        signedRequestJson,
      )
          .timeout(
        const Duration(seconds: 90),
        onTimeout: (EventSink<Map<String, dynamic>> sink) {
          sink.addError(
            StateError('Attachment upload stalled (no server ACK)'),
          );
        },
      ).timeout(const Duration(minutes: 5));

      await for (final statusJson in responseStream) {
        final status = UploadStatusBean.fromJson(statusJson);
        lastStatus = status;
        if (status.isError) {
          throw StateError('Upload failed: ${status.error ?? status.status}');
        }

        if (totalBytes > 0) {
          final uploadedChunk = status.uploadedChunk ?? 0;
          // rsclient: bytesUploaded = uploaded_chunk * chunkSize
          var uploadedBytes = uploadedChunk * effectiveChunk;
          if (uploadedBytes > totalBytes) uploadedBytes = totalBytes;
          if (status.isComplete) {
            reportProgress(0.99);
          } else if (uploadedBytes > 0) {
            reportProgress(uploadedBytes / totalBytes);
          }
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
    } finally {
      if (!controller.isClosed) {
        await controller.close();
      }
    }

    final result = lastStatus;
    if (result == null || !result.isComplete) {
      throw StateError(
        'Attachment upload incomplete: status=${result?.status ?? "none"} '
        'verified=${result?.verified}',
      );
    }
    reportProgress(0.99);
    return result;
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
        if (controller.isClosed) return;
        final end = (offset + chunkSize).clamp(0, data.length);
        controller.add(Uint8List.fromList(data.sublist(offset, end)));
        offset = end;
        // Yield so REQUEST_N / inbound frames can be processed (avoid RS-515).
        await Future<void>.delayed(Duration.zero);
      }
      await controller.close();
    } catch (e) {
      if (!controller.isClosed) {
        await controller.close();
      }
      rethrow;
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

  /// Creates or updates this device token for the signing identity.
  ///
  /// Always pass a **fresh** [nonce] from [getNonce] — nonces are single-use
  /// on all FCM routes (`docs/guide/fcm_token_delete_api.it.pdf` §4).
  Future<Map<String, dynamic>> registerFcmToken({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonce,
    required String fcmToken,
    required String platform,
    String? deviceId,
  }) {
    return _fcmTokenRoute(
      route: ChatServerEndpoints.registerFcmToken,
      keys: keys,
      nonce: nonce,
      fcmToken: fcmToken,
      platform: platform,
      deviceId: deviceId,
    );
  }

  /// Soft-deletes this device token (`is_active = false`, row kept ~30 days).
  ///
  /// Prefer [deleteFcmToken] on identity switch / logout — soft-delete leaves
  /// the PK occupied and blocks the next [registerFcmToken] (same PDF §1).
  Future<Map<String, dynamic>> unregisterFcmToken({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonce,
    required String fcmToken,
    required String platform,
    String? deviceId,
  }) {
    return _fcmTokenRoute(
      route: ChatServerEndpoints.unregisterFcmToken,
      keys: keys,
      nonce: nonce,
      fcmToken: fcmToken,
      platform: platform,
      deviceId: deviceId,
    );
  }

  /// Physically deletes this device's FCM row for the signing identity.
  ///
  /// Use on identity switch and logout, **before** discarding [keys].
  /// Idempotent: missing rows return `success` with `deleted_count: 0`.
  Future<Map<String, dynamic>> deleteFcmToken({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonce,
    required String fcmToken,
    required String platform,
    String? deviceId,
  }) {
    return _fcmTokenRoute(
      route: ChatServerEndpoints.deleteFcmToken,
      keys: keys,
      nonce: nonce,
      fcmToken: fcmToken,
      platform: platform,
      deviceId: deviceId,
    );
  }

  /// Physically deletes every FCM row for the signing identity (all devices).
  ///
  /// [fcmToken] is ignored by the server and may be empty.
  Future<Map<String, dynamic>> deleteAllFcmTokens({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonce,
    String fcmToken = '',
    String platform = 'android',
    String? deviceId,
  }) {
    return _fcmTokenRoute(
      route: ChatServerEndpoints.deleteAllFcmTokens,
      keys: keys,
      nonce: nonce,
      fcmToken: fcmToken,
      platform: platform,
      deviceId: deviceId,
    );
  }

  Future<Map<String, dynamic>> _fcmTokenRoute({
    required String route,
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonce,
    required String fcmToken,
    required String platform,
    String? deviceId,
  }) async {
    final request = await TkmChatCrypto.buildFcmTokenRegistrationRequest(
      keys: keys,
      nonceResponse: nonce,
      fcmToken: fcmToken,
      platform: platform,
      deviceId: deviceId,
    );
    final content = request['fcm_token_registration_signed_content']
        as Map<String, dynamic>?;
    debugPrint(
      'chat[rschat] $route REQUEST '
      'message_type=${request['message_type']} '
      'from=${request['from']} '
      'platform=${content?['platform']} '
      'device_id=${content?['device_id']} '
      'fcm_token=$fcmToken '
      'nonce=${content?['nonce']}',
    );
    try {
      final response = await _requestResponse(route, request);
      final map = response ?? {};
      debugPrint(
        'chat[rschat] $route RESPONSE '
        'success=${map['success']} '
        'error_code=${map['error_code']} '
        'message=${map['message']} '
        'deleted_count=${map['deleted_count']} '
        'registration_time=${map['registration_time']} '
        'body=$map',
      );
      return map;
    } catch (e, st) {
      debugPrint(
        'chat[rschat] $route ERROR '
        'fcm_token=$fcmToken platform=$platform error=$e',
      );
      debugPrint('chat[rschat] $route stack: $st');
      rethrow;
    }
  }

  // --- User profile channel -------------------------------------------------

  Future<Map<String, dynamic>> setUserProfile({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonce,
    required TkmEncryptedProfile profile,
    required List<TkmProfileGrant> grants,
  }) async {
    final request = await TkmChatProfileRequests.buildSetUserProfileRequest(
      keys: keys,
      nonceResponse: nonce,
      profile: profile,
      grants: grants,
    );
    return await _requestResponse(
          ChatServerEndpoints.setUserProfile,
          request,
        ) ??
        {};
  }

  Future<Map<String, dynamic>> putProfileGrants({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonce,
    required int keyEpoch,
    required List<TkmProfileGrant> grants,
  }) async {
    final request = await TkmChatProfileRequests.buildPutProfileGrantsRequest(
      keys: keys,
      nonceResponse: nonce,
      keyEpoch: keyEpoch,
      grants: grants,
    );
    return await _requestResponse(
          ChatServerEndpoints.putProfileGrants,
          request,
        ) ??
        {};
  }

  Future<Map<String, dynamic>> clearUserProfile({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonce,
  }) async {
    final request = await TkmChatProfileRequests.buildClearUserProfileRequest(
      keys: keys,
      nonceResponse: nonce,
    );
    return await _requestResponse(
          ChatServerEndpoints.clearUserProfile,
          request,
        ) ??
        {};
  }

  Future<Map<String, dynamic>> getUserProfile({
    required ChatKeyMaterial keys,
  }) async {
    final request = await TkmChatProfileRequests.buildGetUserProfileRequest(
      keys: keys,
    );
    return await _requestResponse(
          ChatServerEndpoints.getUserProfile,
          request,
        ) ??
        {};
  }

  Future<Map<String, dynamic>> getUserProfilePeer({
    required ChatKeyMaterial keys,
    required String targetPublicKey,
    String? knownBlobHash,
  }) async {
    final request =
        await TkmChatProfileRequests.buildGetUserProfilePeerRequest(
      keys: keys,
      targetPublicKey: targetPublicKey,
      knownBlobHash: knownBlobHash,
    );
    return await _requestResponse(
          ChatServerEndpoints.getUserProfilePeer,
          request,
        ) ??
        {};
  }

  Future<List<TkmProfileDigest>> getProfileDigests({
    required ChatKeyMaterial keys,
    required List<String> targetPublicKeys,
  }) async {
    final request = await TkmChatProfileRequests.buildGetProfileDigestsRequest(
      keys: keys,
      targetPublicKeys: targetPublicKeys,
    );
    final response = await _requestResponse(
          ChatServerEndpoints.getProfileDigests,
          request,
        ) ??
        {};
    final digestsRaw = response['digests'];
    if (digestsRaw is! List) return const [];
    return digestsRaw
        .whereType<Map>()
        .map((e) => TkmProfileDigest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> disconnect() => _client.disconnect();
}
