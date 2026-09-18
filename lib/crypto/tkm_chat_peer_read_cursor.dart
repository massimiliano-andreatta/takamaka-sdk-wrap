/// Monotonic peer-read cursor (READ_RECEIPT_DESIGN §12.2).
class TkmPeerReadCursor {
  const TkmPeerReadCursor({
    this.lastReadMessageSignature,
    this.lastReadTimestamp,
  });

  final String? lastReadMessageSignature;
  final int? lastReadTimestamp;

  /// Advances when [candidateTimestamp] is newer, or equal with a strictly
  /// greater signature (lexicographic tie-break). Older timestamps are ignored.
  TkmPeerReadCursorMerge merge({
    required String candidateSignature,
    required int candidateTimestamp,
  }) {
    final currentTs = lastReadTimestamp;
    if (currentTs == null) {
      return TkmPeerReadCursorMerge(
        advanced: true,
        cursor: TkmPeerReadCursor(
          lastReadMessageSignature: candidateSignature,
          lastReadTimestamp: candidateTimestamp,
        ),
      );
    }
    if (candidateTimestamp > currentTs) {
      return TkmPeerReadCursorMerge(
        advanced: true,
        cursor: TkmPeerReadCursor(
          lastReadMessageSignature: candidateSignature,
          lastReadTimestamp: candidateTimestamp,
        ),
      );
    }
    if (candidateTimestamp < currentTs) {
      return TkmPeerReadCursorMerge(advanced: false, cursor: this);
    }
    final currentSig = lastReadMessageSignature ?? '';
    if (candidateSignature.compareTo(currentSig) > 0) {
      return TkmPeerReadCursorMerge(
        advanced: true,
        cursor: TkmPeerReadCursor(
          lastReadMessageSignature: candidateSignature,
          lastReadTimestamp: candidateTimestamp,
        ),
      );
    }
    return TkmPeerReadCursorMerge(advanced: false, cursor: this);
  }
}

class TkmPeerReadCursorMerge {
  const TkmPeerReadCursorMerge({
    required this.advanced,
    required this.cursor,
  });

  final bool advanced;
  final TkmPeerReadCursor cursor;
}
