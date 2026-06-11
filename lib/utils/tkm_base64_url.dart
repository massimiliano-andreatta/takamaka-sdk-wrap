import 'dart:convert';
import 'dart:typed_data';

/// Takamaka URL-safe Base64 with `.` padding (BouncyCastle UrlBase64 style).
abstract final class TkmBase64Url {
  static String encode(Uint8List bytes) {
    return base64Url.encode(bytes).replaceAll('=', '.');
  }

  static Uint8List decode(String value) {
    final normalized = value.replaceAll('.', '=');
    return Uint8List.fromList(base64Url.decode(normalized));
  }

  /// Accepts standard base64 (`+/=`) or Takamaka URL-safe (`.` padding).
  static Uint8List decodeFlexible(String value) {
    if (value.contains('+') ||
        value.contains('/') ||
        value.endsWith('=')) {
      return Uint8List.fromList(base64.decode(value));
    }
    return decode(value);
  }

  static String encodeEd25519PublicKey(Uint8List publicKeyBytes) {
    return encode(publicKeyBytes);
  }
}
