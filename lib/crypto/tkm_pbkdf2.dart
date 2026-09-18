import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// PBKDF2-HMAC-SHA512 matching wallet-core / Java `TkmSignUtils.PWHash`.
abstract final class TkmPbkdf2 {
  static Uint8List deriveKey({
    required String password,
    required String salt,
    required int iterations,
    required int keyLengthBits,
  }) {
    final keyLengthBytes = keyLengthBits ~/ 8;
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA512Digest(), 128));
    pbkdf2.init(
      Pbkdf2Parameters(
        Uint8List.fromList(utf8.encode(salt)),
        iterations,
        keyLengthBytes,
      ),
    );
    final key = Uint8List(keyLengthBytes);
    pbkdf2.deriveKey(
      Uint8List.fromList(utf8.encode(password)),
      0,
      key,
      0,
    );
    return key;
  }
}
