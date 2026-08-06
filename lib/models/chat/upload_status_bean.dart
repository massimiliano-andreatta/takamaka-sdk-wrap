/// Streaming upload progress response from rschat `submitattachment`.
class UploadStatusBean {
  const UploadStatusBean({
    this.uploadContentIdentifyingHash,
    this.status,
    this.uploadedChunk,
    this.error,
  });

  final String? uploadContentIdentifyingHash;
  final String? status;
  final int? uploadedChunk;
  final String? error;

  /// Java-style completion flag (CLIENT_API_GUIDE: last emit with verified=true).
  final bool? verified;
  final int? size;

  factory UploadStatusBean.fromJson(Map<String, dynamic> json) {
    return UploadStatusBean(
      uploadContentIdentifyingHash:
          json['upload_content_id_hash'] as String? ??
              json['signature'] as String?,
      status: json['status'] as String?,
      uploadedChunk: (json['uploaded_chunk'] as num?)?.toInt(),
      error: json['error'] as String?,
      verified: json['verified'] as bool?,
      size: (json['size'] as num?)?.toInt(),
    );
  }

  bool get isError =>
      status == 'ERROR' ||
      status == 'TRANSFER_FAIL' ||
      status == 'SIGNATURE_REJECTED' ||
      status == 'CONCURRENT_UPLOAD_ALREADY_RUNNING' ||
      status == 'CONTENT_NOT_FOUND' ||
      (error != null && error!.isNotEmpty);

  /// Server may emit either Flutter-style status strings or Java `verified`.
  bool get isComplete =>
      verified == true ||
      status == 'READY_FOR_DOWNLOAD' ||
      status == 'COMPLETE';
}
