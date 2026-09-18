import 'package:takamaka_sdk_wrap/constants/chat_message_types.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_inbound_envelope.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';

enum TkmDeleteHonorOutcome {
  honored,
  invalidSignature,
  notOwner,
  unknownTarget,
  selfAuthored,
  malformed,
}

class TkmDeleteTombstone {
  const TkmDeleteTombstone({
    required this.conversationHashName,
    required this.targetMessageSignature,
    required this.deletedBy,
    this.encryptedFileHashes = const <String>[],
    this.encryptedReason,
    this.clientTimestamp,
  });

  final String conversationHashName;
  final String targetMessageSignature;
  final String deletedBy;
  final List<String> encryptedFileHashes;
  final Map<String, dynamic>? encryptedReason;
  final int? clientTimestamp;

  bool get hasAttachments => encryptedFileHashes.isNotEmpty;
}

class TkmDeleteHonorResult {
  const TkmDeleteHonorResult._(this.outcome, [this.tombstone]);

  final TkmDeleteHonorOutcome outcome;
  final TkmDeleteTombstone? tombstone;

  bool get shouldApply =>
      outcome == TkmDeleteHonorOutcome.honored && tombstone != null;
}

/// Independently verifies a peer's DR-025 delete (rsclient `MessageDeleteHonor`).
abstract final class TkmChatDeleteHonor {
  static Future<bool> verifySignature(Map<String, dynamic> envelope) async {
    final from = envelope['from'] as String? ?? '';
    final signature = envelope['signature'] as String? ?? '';
    final signatureType = envelope['signature_type'] as String? ?? '';
    final pl = envelope['pl'];
    if (from.isEmpty || signature.isEmpty || pl is! Map) return false;
    if (signatureType != TkmChatSigning.signatureType) return false;
    try {
      return TkmChatSigning.verifyCanonicalJsonJavaCompatible(
        publicKeyUrl64: from,
        signatureUrl64: signature,
        signedContent: Map<String, dynamic>.from(pl),
      );
    } catch (_) {
      return false;
    }
  }

  static Future<TkmDeleteHonorResult> honor(
    TkmInboundEnvelope envelope, {
    required String? targetMessageAuthor,
    String? selfPublicKey,
    bool skipSelfAuthored = false,
  }) async {
    if (!envelope.isDelete || envelope.json == null) {
      return const TkmDeleteHonorResult._(TkmDeleteHonorOutcome.malformed);
    }
    return honorJson(
      envelope.json!,
      targetMessageAuthor: targetMessageAuthor,
      selfPublicKey: selfPublicKey,
      skipSelfAuthored: skipSelfAuthored,
    );
  }

  static Future<TkmDeleteHonorResult> honorJson(
    Map<String, dynamic> envelope, {
    required String? targetMessageAuthor,
    String? selfPublicKey,
    bool skipSelfAuthored = false,
  }) async {
    if ((envelope['message_type'] as String?) !=
        ChatMessageTypes.deleteMessage) {
      return const TkmDeleteHonorResult._(TkmDeleteHonorOutcome.malformed);
    }
    final plRaw = envelope['pl'];
    if (plRaw is! Map) {
      return const TkmDeleteHonorResult._(TkmDeleteHonorOutcome.malformed);
    }
    final pl = Map<String, dynamic>.from(plRaw);
    final conversationHash = pl['conversation_hash_name'] as String? ?? '';
    final targetSignature = pl['target_message_signature'] as String? ?? '';
    if (conversationHash.isEmpty || targetSignature.isEmpty) {
      return const TkmDeleteHonorResult._(TkmDeleteHonorOutcome.malformed);
    }

    final from = envelope['from'] as String? ?? '';
    if (skipSelfAuthored && selfPublicKey != null && selfPublicKey == from) {
      return const TkmDeleteHonorResult._(TkmDeleteHonorOutcome.selfAuthored);
    }

    if (!await verifySignature(envelope)) {
      return const TkmDeleteHonorResult._(
        TkmDeleteHonorOutcome.invalidSignature,
      );
    }

    if (targetMessageAuthor == null || targetMessageAuthor.isEmpty) {
      return const TkmDeleteHonorResult._(TkmDeleteHonorOutcome.unknownTarget);
    }
    if (targetMessageAuthor != from) {
      return const TkmDeleteHonorResult._(TkmDeleteHonorOutcome.notOwner);
    }

    final rawEfh = pl['target_efh'];
    final efh = rawEfh is List
        ? rawEfh.whereType<String>().toList(growable: false)
        : const <String>[];
    Map<String, dynamic>? reason;
    final rawReason = pl['reason'];
    if (rawReason is Map) {
      reason = Map<String, dynamic>.from(rawReason);
    }

    return TkmDeleteHonorResult._(
      TkmDeleteHonorOutcome.honored,
      TkmDeleteTombstone(
        conversationHashName: conversationHash,
        targetMessageSignature: targetSignature,
        deletedBy: from,
        encryptedFileHashes: efh,
        encryptedReason: reason,
        clientTimestamp: (pl['client_ts'] as num?)?.toInt(),
      ),
    );
  }
}
