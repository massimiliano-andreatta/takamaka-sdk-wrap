import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:takamaka_sdk_wrap/models/chat/tkm_chat_profile_models.dart';

/// Re-encodes a user-picked image to fit the profile avatar cap (registry §4.6).
///
/// Never put the original file into the card. Output is JPEG.
abstract final class TkmChatProfileAvatarEncoder {
  static const List<int> _qualityLadder = [85, 75, 65, 55, 45];
  static const List<int> _edgeLadder = [512, 384, 256, 192];

  /// Encodes [source] to JPEG ≤ [maxBytes] (default 128 KiB).
  ///
  /// Throws [StateError] only if both quality and edge ladders are exhausted.
  static TkmEncodedAvatar encode(
    Uint8List source,
    int maxBytes, {
    int maxEdgePx = TkmChatProfileConstants.maxAvatarEdgePx,
  }) {
    final decoded = img.decodeImage(source);
    if (decoded == null) {
      throw StateError('Could not decode avatar image');
    }
    final pixels = decoded.width * decoded.height;
    if (pixels > TkmChatProfileConstants.maxPixelGuard) {
      throw StateError(
        'Avatar pixel count $pixels exceeds guard '
        '${TkmChatProfileConstants.maxPixelGuard}',
      );
    }

    final edges = <int>[
      for (final e in _edgeLadder)
        if (e <= maxEdgePx) e,
    ];
    if (edges.isEmpty) edges.add(maxEdgePx.clamp(192, 512));

    for (final edge in edges) {
      var working = decoded;
      final longest = working.width > working.height
          ? working.width
          : working.height;
      if (longest > edge) {
        working = img.copyResize(
          working,
          width: working.width >= working.height ? edge : null,
          height: working.height > working.width ? edge : null,
          interpolation: img.Interpolation.linear,
        );
      }
      // Flatten alpha onto white (JPEG has no alpha).
      working = img.bakeOrientation(working);
      final flat = img.Image(
        width: working.width,
        height: working.height,
        numChannels: 3,
      );
      for (final p in working) {
        final a = p.aNormalized;
        final r = (p.rNormalized * a + (1 - a)).clamp(0.0, 1.0);
        final g = (p.gNormalized * a + (1 - a)).clamp(0.0, 1.0);
        final b = (p.bNormalized * a + (1 - a)).clamp(0.0, 1.0);
        flat.setPixelRgb(
          p.x,
          p.y,
          (r * 255).round(),
          (g * 255).round(),
          (b * 255).round(),
        );
      }

      for (final quality in _qualityLadder) {
        final encoded = img.encodeJpg(flat, quality: quality);
        if (encoded.length <= maxBytes) {
          return TkmEncodedAvatar(
            bytes: encoded,
            mediaType: 'image/jpeg',
            width: flat.width,
            height: flat.height,
          );
        }
      }
    }

    throw StateError(
      'Avatar could not be compressed under $maxBytes bytes',
    );
  }
}
