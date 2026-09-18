/// Client-side transport-sizing policy for the `serverinfo` manifest
/// (DR-022 / DR-023). Port of rsclient `ManifestLimits`.
class TkmChatManifestLimits {
  TkmChatManifestLimits._();

  /// Assumed server frame ceiling when the manifest omits it (older server).
  static const int defaultMaxFrameBytes = 64 * 1024;

  /// Implausibly-small floor: kept above [minUploadChunkBytes] + overhead.
  static const int floorFrameBytes = 32 * 1024;

  /// Own WS decoder ceiling (Java `ClientRequestor.MAX_FRAME_PAYLOAD_LENGTH`).
  static const int clientOwnMaxFrameBytes = 2 * 1024 * 1024;

  /// Absurdity backstop (OOM/abuse guard).
  static const int absurdCeilFrameBytes = 16 * 1024 * 1024;

  /// Headroom under the frame ceiling for RSocket/WS header + metadata.
  static const int frameOverheadBytes = 8 * 1024;

  /// Lower bound for the upload chunk.
  static const int minUploadChunkBytes = 16 * 1024;

  /// Desktop/CLI upload target.
  static const int desktopUploadTargetBytes = 1024 * 1024;

  /// Mobile upload target (tkmChat / takamaka-flutter-old).
  static const int mobileUploadTargetBytes = 256 * 1024;

  static TkmChatManifestResolution resolve(
    int advertisedFrameBytes,
    int uploadTargetBytes,
  ) {
    final int effective;
    final TkmChatManifestReason reason;
    if (advertisedFrameBytes <= 0) {
      effective = defaultMaxFrameBytes;
      reason = TkmChatManifestReason.absent;
    } else if (advertisedFrameBytes < floorFrameBytes) {
      effective = defaultMaxFrameBytes;
      reason = TkmChatManifestReason.belowFloor;
    } else if (advertisedFrameBytes > absurdCeilFrameBytes) {
      effective = defaultMaxFrameBytes;
      reason = TkmChatManifestReason.absurdRejected;
    } else if (advertisedFrameBytes > clientOwnMaxFrameBytes) {
      effective = clientOwnMaxFrameBytes;
      reason = TkmChatManifestReason.clampedToClientMax;
    } else {
      effective = advertisedFrameBytes;
      reason = TkmChatManifestReason.ok;
    }
    final ceiling = effective - frameOverheadBytes;
    var chunk = uploadTargetBytes < ceiling ? uploadTargetBytes : ceiling;
    final floor = minUploadChunkBytes < ceiling ? minUploadChunkBytes : ceiling;
    if (chunk < floor) chunk = floor;
    return TkmChatManifestResolution(
      advertisedFrameBytes: advertisedFrameBytes,
      effectiveFrameBytes: effective,
      uploadChunkBytes: chunk,
      reason: reason,
    );
  }
}

enum TkmChatManifestReason {
  absent,
  belowFloor,
  absurdRejected,
  clampedToClientMax,
  ok,
}

class TkmChatManifestResolution {
  const TkmChatManifestResolution({
    required this.advertisedFrameBytes,
    required this.effectiveFrameBytes,
    required this.uploadChunkBytes,
    required this.reason,
  });

  final int advertisedFrameBytes;
  final int effectiveFrameBytes;
  final int uploadChunkBytes;
  final TkmChatManifestReason reason;
}

/// Connect-time result of probing `serverinfo` (rsclient `NegotiatedTransport`).
class TkmChatNegotiatedTransport {
  const TkmChatNegotiatedTransport({
    required this.resolution,
    required this.manifestVersion,
    required this.serverVersion,
    required this.clientDecoderMaxBytes,
    this.editDeleteWindowMs = 0,
    this.supportedRoutes = const <String>[],
    this.maxAttachmentSizeBytes = 0,
  });

  final TkmChatManifestResolution resolution;
  final String manifestVersion;
  final String serverVersion;
  final int clientDecoderMaxBytes;
  final int editDeleteWindowMs;
  final List<String> supportedRoutes;
  final int maxAttachmentSizeBytes;

  int get uploadChunkBytes => resolution.uploadChunkBytes;

  /// True when the server advertised a route set AND [route] is absent.
  bool isKnownUnsupported(String route) =>
      supportedRoutes.isNotEmpty && !supportedRoutes.contains(route);
}
