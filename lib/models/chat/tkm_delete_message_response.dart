/// ACK for `deletemessage` (DR-025). Port of Java `DeleteMessageResponseBean`.
class TkmDeleteMessageResponse {
  const TkmDeleteMessageResponse({
    required this.accepted,
    this.targetMessageSignature,
    this.serverDeleteTime,
    this.error,
    this.purgedAttachmentCount = 0,
  });

  final bool accepted;
  final String? targetMessageSignature;
  final int? serverDeleteTime;
  final String? error;
  final int purgedAttachmentCount;

  static const String errorRateLimited = 'rate_limited';
  static const String errorInvalidSignature = 'invalid_signature';
  static const String errorNotOwner = 'not_owner';
  static const String errorNotMember = 'not_member';
  static const String errorWindowExpired = 'window_expired';
  static const String errorNotFound = 'not_found';
  static const String errorInternal = 'internal_error';

  /// Accepted, or idempotent re-delete (`not_found`).
  bool get isSuccess => accepted || error == errorNotFound;

  factory TkmDeleteMessageResponse.fromJson(Map<String, dynamic> json) {
    return TkmDeleteMessageResponse(
      accepted: json['accepted'] == true,
      targetMessageSignature: json['target_message_signature'] as String?,
      serverDeleteTime: (json['server_delete_time'] as num?)?.toInt(),
      error: json['error'] as String?,
      purgedAttachmentCount:
          (json['purged_attachment_count'] as num?)?.toInt() ?? 0,
    );
  }
}
