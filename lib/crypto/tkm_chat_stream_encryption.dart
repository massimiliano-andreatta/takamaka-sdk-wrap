import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:pointycastle/export.dart';
import 'package:takamaka_sdk_wrap/models/chat/stream_encrypted_descriptor.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_base64_url.dart';

/// Streaming AES-GCM encryption for rschat attachments (Java TkmEncryptionUtils).
///
/// [StreamEncryptedDescriptor.encryptedContentHash] is SHA3-256 of the ciphertext
/// **bytes** (DR-030), not of the base64 wire text. [StreamEncryptionResult.encryptedData]
/// remains UTF-8 of standard base64; placeholder `size` stays that encoded length.
class TkmChatStreamEncryption {
  TkmChatStreamEncryption._();

  static const int iterations = 20000;
  static const int keyLengthBits = 256;
  static const int ivByteLength = 12;
  static const int tagBitLength = 128;

  static final _secureRandom = FortunaRandom()
    ..seed(KeyParameter(Uint8List.fromList(
      List.generate(32, (_) => Random.secure().nextInt(256)),
    )));

  static StreamEncryptionResult encrypt({
    required String password,
    required String scope,
    required Uint8List plaintext,
  }) {
    final salt = _generateRandomSaltWithScope(scope);
    final saltBytes = _hexToBytes(salt);
    final iv = _generateIv(ivByteLength);

    final key = _deriveKeyWithByteSalt(
      password: password,
      saltBytes: saltBytes,
      iterations: iterations,
      keyLengthBits: keyLengthBits,
    );

    final plaintextHashHex = computeHashHex(plaintext);

    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      true,
      AEADParameters(
        KeyParameter(key),
        tagBitLength,
        iv,
        Uint8List(0),
      ),
    );
    final ciphertext = cipher.process(plaintext);

    // DR-030: hash ciphertext BYTES, not the base64 wire text (wrapping/alphabet
    // must not affect attachment identity). Wire body stays standard base64 UTF-8.
    final encryptedHashHex = computeHashHex(ciphertext);
    final base64Encoded =
        Uint8List.fromList(utf8.encode(base64.encode(ciphertext)));

    final descriptor = StreamEncryptedDescriptor.standard(
      salt: salt,
      iv: _bytesToHex(iv),
      encryptedContentHash: encryptedHashHex,
    );

    return StreamEncryptionResult(
      plaintextHashHex: plaintextHashHex,
      descriptor: descriptor,
      encryptedData: base64Encoded,
    );
  }

  /// Runs [encrypt] off the UI isolate (parity with rsclient `encryptAsync`).
  static Future<StreamEncryptionResult> encryptAsync({
    required String password,
    required String scope,
    required Uint8List plaintext,
  }) {
    return compute(
      _encryptInIsolate,
      _EncryptIsolateParams(
        password: password,
        scope: scope,
        plaintext: plaintext,
      ),
    );
  }

  static Uint8List decrypt({
    required String password,
    required StreamEncryptedDescriptor descriptor,
    required Uint8List encryptedData,
    String? expectedPlaintextHashHex,
  }) {
    // DR-030: decode first, then hash ciphertext BYTES (parity rsclient
    // stream_encryption + Java Base64InputStream leniency).
    final ciphertext = decodeWireBody(encryptedData);

    final actualEncHashHex = computeHashHex(ciphertext);
    if (descriptor.encryptedContentHash != null &&
        descriptor.encryptedContentHash != actualEncHashHex) {
      final legacyWireHex = computeHashHex(encryptedData);
      final preDr030 = descriptor.encryptedContentHash == legacyWireHex;
      throw StateError(
        'Encrypted content hash mismatch: expected '
        '${descriptor.encryptedContentHash}, got $actualEncHashHex'
        '${preDr030 ? ' — PRE-DR-030 attachment: declared hash is SHA3-256 of '
            'the base64 WIRE TEXT (not tampering; no remediation)' : ''}',
      );
    }

    final saltBytes = _hexToBytes(descriptor.salt);
    final iv = _hexToBytes(descriptor.iv);
    final key = _deriveKeyWithByteSalt(
      password: password,
      saltBytes: saltBytes,
      iterations: descriptor.iterations ?? iterations,
      keyLengthBits: descriptor.outputKeyLengthBit ?? keyLengthBits,
    );

    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      false,
      AEADParameters(
        KeyParameter(key),
        descriptor.tagLengthBit ?? tagBitLength,
        iv,
        Uint8List(0),
      ),
    );
    final plaintext = cipher.process(ciphertext);

    if (expectedPlaintextHashHex != null) {
      final actualPlainHashHex = computeHashHex(plaintext);
      if (expectedPlaintextHashHex != actualPlainHashHex) {
        throw StateError(
          'Plaintext hash mismatch: expected $expectedPlaintextHashHex, '
          'got $actualPlainHashHex',
        );
      }
    }

    return plaintext;
  }

  /// Decodes a received wire body as leniently as Java Commons Base64InputStream.
  ///
  /// Strips non-alphabet chars (CRLF, spaces, `=` / `.` padding), drops an
  /// incomplete final quantum, re-derives `=` padding. Identity is the DR-030
  /// hash over the decoded bytes — not this decoding step.
  static Uint8List decodeWireBody(Uint8List encryptedData) {
    final raw = utf8.decode(encryptedData, allowMalformed: true);
    final buf = StringBuffer();
    for (final c in raw.codeUnits) {
      final isAlphabet = (c >= 0x41 && c <= 0x5A) ||
          (c >= 0x61 && c <= 0x7A) ||
          (c >= 0x30 && c <= 0x39) ||
          c == 0x2B ||
          c == 0x2F ||
          c == 0x2D ||
          c == 0x5F;
      if (isAlphabet) buf.writeCharCode(c);
    }
    var s = buf.toString();
    final remainder = s.length % 4;
    if (remainder == 1) {
      s = s.substring(0, s.length - 1);
    } else if (remainder != 0) {
      s = s.padRight(s.length + (4 - remainder), '=');
    }
    return Uint8List.fromList(base64.decode(s));
  }

  static String computeHashHex(Uint8List data) {
    final digest = SHA3Digest(256);
    return _bytesToHex(digest.process(data));
  }

  static String computePlaintextHashUrl64(Uint8List data) {
    final digest = SHA3Digest(256);
    return TkmBase64Url.encode(Uint8List.fromList(digest.process(data)));
  }

  /// SHA3 hash off the UI isolate for large attachments.
  static Future<String> computePlaintextHashUrl64Async(Uint8List data) {
    return compute(_hashUrl64InIsolate, data);
  }

  static String _generateRandomSaltWithScope(String scope) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final randomChars = StringBuffer();
    for (var i = 0; i < 256; i++) {
      randomChars.write(chars[_secureRandom.nextUint8() % chars.length]);
    }
    final inputBytes =
        Uint8List.fromList(utf8.encode(scope + randomChars.toString()));
    return computeHashHex(inputBytes);
  }

  static Uint8List _generateIv(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextUint8();
    }
    return bytes;
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  static Uint8List _deriveKeyWithByteSalt({
    required String password,
    required Uint8List saltBytes,
    required int iterations,
    required int keyLengthBits,
  }) {
    final keyLengthBytes = keyLengthBits ~/ 8;
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA512Digest(), 128));
    pbkdf2.init(Pbkdf2Parameters(saltBytes, iterations, keyLengthBytes));
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

class _EncryptIsolateParams {
  const _EncryptIsolateParams({
    required this.password,
    required this.scope,
    required this.plaintext,
  });

  final String password;
  final String scope;
  final Uint8List plaintext;
}

StreamEncryptionResult _encryptInIsolate(_EncryptIsolateParams params) {
  return TkmChatStreamEncryption.encrypt(
    password: params.password,
    scope: params.scope,
    plaintext: params.plaintext,
  );
}

String _hashUrl64InIsolate(Uint8List data) {
  return TkmChatStreamEncryption.computePlaintextHashUrl64(data);
}

class StreamEncryptionResult {
  const StreamEncryptionResult({
    required this.plaintextHashHex,
    required this.descriptor,
    required this.encryptedData,
  });

  final String plaintextHashHex;
  final StreamEncryptedDescriptor descriptor;
  final Uint8List encryptedData;
}
