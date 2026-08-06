import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:pointycastle/export.dart';
import 'package:takamaka_sdk_wrap/models/chat/stream_encrypted_descriptor.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_base64_url.dart';

/// Streaming AES-GCM encryption for rschat attachments (Java TkmEncryptionUtils).
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

    final base64Encoded =
        Uint8List.fromList(utf8.encode(base64.encode(ciphertext)));
    final encryptedHashHex = computeHashHex(base64Encoded);

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
    final actualEncHashHex = computeHashHex(encryptedData);
    if (descriptor.encryptedContentHash != null &&
        descriptor.encryptedContentHash != actualEncHashHex) {
      throw StateError(
        'Encrypted content hash mismatch: expected '
        '${descriptor.encryptedContentHash}, got $actualEncHashHex',
      );
    }

    final base64String =
        utf8.decode(encryptedData).replaceAll(RegExp(r'\s'), '');
    final ciphertext = base64.decode(base64String);

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
    final plaintext = cipher.process(Uint8List.fromList(ciphertext));

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
