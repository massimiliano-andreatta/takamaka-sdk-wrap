import 'dart:convert';

import 'package:takamaka_sdk_wrap/constants/chat_message_types.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_crypto.dart';

/// Kind of signed command on `retrievemessages` / `retrieveallmessages`.
enum TkmInboundEnvelopeKind {
  message,
  delete,
  unknown,
  malformed,
}

/// Classifies a stream item before decrypt. Port of rsclient `InboundEnvelope`.
///
/// A `DELETE_MESSAGE` envelope has no `basic_message_signed_content_bean`.
/// Treating it as a normal message silently drops every peer delete.
class TkmInboundEnvelope {
  const TkmInboundEnvelope._({
    required this.kind,
    this.messageType,
    this.from,
    this.signature,
    this.json,
    this.problem,
  });

  final TkmInboundEnvelopeKind kind;
  final String? messageType;
  final String? from;
  final String? signature;
  final Map<String, dynamic>? json;
  final String? problem;

  bool get isDelete => kind == TkmInboundEnvelopeKind.delete && json != null;

  bool get isMessage => kind == TkmInboundEnvelopeKind.message;

  Map<String, dynamic>? get pl {
    final raw = json?['pl'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String? get targetMessageSignature =>
      pl?['target_message_signature'] as String?;

  String? get conversationHashName {
    final fromPl = pl?['conversation_hash_name'] as String?;
    if (fromPl != null && fromPl.isNotEmpty) return fromPl;
    if (json == null) return null;
    return TkmChatCrypto.conversationHashFromEnvelope(json!);
  }

  static TkmInboundEnvelope parse(String messageJson) {
    if (messageJson.isEmpty) {
      return const TkmInboundEnvelope._(
        kind: TkmInboundEnvelopeKind.malformed,
        problem: 'message_json is empty',
      );
    }
    try {
      final value = jsonDecode(messageJson);
      if (value is! Map) {
        return const TkmInboundEnvelope._(
          kind: TkmInboundEnvelopeKind.malformed,
          problem: 'message_json is not a JSON object',
        );
      }
      return fromJson(Map<String, dynamic>.from(value));
    } catch (e) {
      return TkmInboundEnvelope._(
        kind: TkmInboundEnvelopeKind.malformed,
        problem: 'message_json is not valid JSON: $e',
      );
    }
  }

  static TkmInboundEnvelope fromJson(Map<String, dynamic> decoded) {
    final messageType = decoded['message_type'] as String?;
    final from = decoded['from'] as String?;
    final signature = decoded['signature'] as String?;
    if (messageType == null || from == null || signature == null) {
      return TkmInboundEnvelope._(
        kind: TkmInboundEnvelopeKind.malformed,
        json: decoded,
        messageType: messageType,
        from: from,
        signature: signature,
        problem: 'envelope is missing from/signature/message_type',
      );
    }

    if (messageType == ChatMessageTypes.deleteMessage) {
      final pl = decoded['pl'];
      if (pl is! Map) {
        return TkmInboundEnvelope._(
          kind: TkmInboundEnvelopeKind.malformed,
          messageType: messageType,
          from: from,
          signature: signature,
          json: decoded,
          problem: 'DELETE_MESSAGE envelope has an unusable pl',
        );
      }
      return TkmInboundEnvelope._(
        kind: TkmInboundEnvelopeKind.delete,
        messageType: messageType,
        from: from,
        signature: signature,
        json: decoded,
      );
    }

    final isMessage = messageType == ChatMessageTypes.topicMessage ||
        messageType == ChatMessageTypes.topicMessageMedia;
    return TkmInboundEnvelope._(
      kind: isMessage
          ? TkmInboundEnvelopeKind.message
          : TkmInboundEnvelopeKind.unknown,
      messageType: messageType,
      from: from,
      signature: signature,
      json: decoded,
    );
  }

  static TkmInboundEnvelope fromStreamEvent(Map<String, dynamic> event) {
    final raw = event['message_json'] ?? event['messageJson'];
    if (raw is String) return parse(raw);
    if (raw is Map) {
      return fromJson(Map<String, dynamic>.from(raw));
    }
    if (event.containsKey('message_type') ||
        event.containsKey('basic_message_signed_content_bean') ||
        event.containsKey('basic_message_signed_content')) {
      return fromJson(Map<String, dynamic>.from(event));
    }
    return const TkmInboundEnvelope._(
      kind: TkmInboundEnvelopeKind.malformed,
      problem: 'stream event has no message_json envelope',
    );
  }
}
