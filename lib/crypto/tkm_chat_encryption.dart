import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/digests/sha3.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_pbkdf2.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_base64_url.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_canonical_json.dart';

/// Password-based encryption compatible with Java [TkmEncryptionUtils] v0_1_a.
///
/// Wire JSON uses compact keys from [io.takamaka.extra.beans.EncMessageBean]
/// (`pa`, `it`, `tr`, `ka`, `tv`, `kl`, `ec`, `em`) as in blockchain payloads.
abstract final class TkmChatEncryption {
  static const int _iterations = 20000;
  static const String _scopeTopicCreation = 'TOPIC_CREATION';
  static const String _scopeTopicMessage = 'TOPIC_MESSAGE';

  static const String _wirePasswordAlgorithm = 'PBKDF2WithHmacSHA512';
  static const String _wireKeyAlgorithm = 'AES';
  static const String _wireEncoding = 'UTF-8';

  /// PBKDF2 (20k iterations) costs ~50-300ms on mobile; the scope salt is a
  /// constant per wire scope, so the derived AES key is identical for every
  /// message of a conversation. Memoize it to keep per-message work cheap.
  static const int _derivedKeyCacheLimit = 64;
  static final LinkedHashMap<String, Uint8List> _derivedKeyCache =
      LinkedHashMap<String, Uint8List>();
  static final Map<String, Future<void>> _prewarmInFlight = {};

  static String _derivedKeyCacheKey({
    required String password,
    required String salt,
    required int iterations,
    required int keyLengthBits,
  }) =>
      '$iterations|$keyLengthBits|$salt|$password';

  static Uint8List _deriveScopeKeyCached({
    required String password,
    required String salt,
    required int iterations,
    required int keyLengthBits,
  }) {
    final cacheKey = _derivedKeyCacheKey(
      password: password,
      salt: salt,
      iterations: iterations,
      keyLengthBits: keyLengthBits,
    );
    final cached = _derivedKeyCache.remove(cacheKey);
    if (cached != null) {
      // Re-insert to keep LRU ordering.
      _derivedKeyCache[cacheKey] = cached;
      return cached;
    }
    final key = TkmPbkdf2.deriveKey(
      password: password,
      salt: salt,
      iterations: iterations,
      keyLengthBits: keyLengthBits,
    );
    _cacheDerivedKey(cacheKey, key);
    return key;
  }

  static void _cacheDerivedKey(String cacheKey, Uint8List key) {
    _derivedKeyCache[cacheKey] = key;
    while (_derivedKeyCache.length > _derivedKeyCacheLimit) {
      _derivedKeyCache.remove(_derivedKeyCache.keys.first);
    }
  }

  /// Derives the conversation AES keys (both scopes) in a background isolate
  /// and seeds the in-memory cache, so later encrypt/decrypt calls on the UI
  /// isolate are cheap. Safe to call repeatedly (deduped / cache-aware).
  static Future<void> prewarmConversationKey(
    String symmetricKey, {
    int iterations = _iterations,
    int keyLengthBits = 256,
  }) async {
    if (symmetricKey.isEmpty) return;
    const scopes = [_scopeTopicCreation, _scopeTopicMessage];
    final missing = <String>[];
    for (final scope in scopes) {
      final cacheKey = _derivedKeyCacheKey(
        password: symmetricKey,
        salt: scope,
        iterations: iterations,
        keyLengthBits: keyLengthBits,
      );
      if (!_derivedKeyCache.containsKey(cacheKey)) {
        missing.add(scope);
      }
    }
    if (missing.isEmpty) return;

    final inFlightKey = '$iterations|$keyLengthBits|$symmetricKey';
    final inFlight = _prewarmInFlight[inFlightKey];
    if (inFlight != null) return inFlight;

    final future = _prewarmScopes(
      symmetricKey: symmetricKey,
      scopes: missing,
      iterations: iterations,
      keyLengthBits: keyLengthBits,
    ).whenComplete(() {
      _prewarmInFlight.remove(inFlightKey);
    });
    _prewarmInFlight[inFlightKey] = future;
    return future;
  }

  static Future<void> _prewarmScopes({
    required String symmetricKey,
    required List<String> scopes,
    required int iterations,
    required int keyLengthBits,
  }) async {
    final params = _DeriveScopeKeysParams(
      password: symmetricKey,
      scopes: scopes,
      iterations: iterations,
      keyLengthBits: keyLengthBits,
    );
    final keys = kIsWeb
        ? _deriveScopeKeysBlocking(params)
        : await compute(_deriveScopeKeysBlocking, params);
    for (var i = 0; i < scopes.length; i++) {
      _cacheDerivedKey(
        _derivedKeyCacheKey(
          password: symmetricKey,
          salt: scopes[i],
          iterations: iterations,
          keyLengthBits: keyLengthBits,
        ),
        keys[i],
      );
    }
  }

  /// Visible for tests only.
  @visibleForTesting
  static void clearDerivedKeyCache() {
    _derivedKeyCache.clear();
    _prewarmInFlight.clear();
  }

  static String generateSymmetricKey({int length = 400}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  /// 32-char alphanumeric salt for topic title hashing (SERVER_API_GUIDE §5.4).
  static String generateConversationSalt() {
    return generateSymmetricKey(length: 32);
  }

  /// Matches Java [TkmSignUtils.Hash256B64URL] (SHA-256).
  static String hash256B64Url(String input) {
    final digest = crypto.sha256.convert(utf8.encode(input));
    return TkmBase64Url.encode(Uint8List.fromList(digest.bytes));
  }

  /// SHA3-256 base64url (SERVER_API_GUIDE §5.4 topic_title_hash).
  static String hashSha3_256B64Url(String input) {
    final digest =
        SHA3Digest(256).process(Uint8List.fromList(utf8.encode(input)));
    return TkmBase64Url.encode(digest);
  }

  /// Jackson [EncMessageBean] field names for rschat signed payloads.
  ///
  /// Salt/IV are embedded in the ciphertext (first 32 bytes), not separate JSON
  /// fields — the Java bean used by rschat does not expose them on the wire.
  static Map<String, dynamic> toWireEncMessage(Map<String, dynamic> internal) {
    // SerializerUtils compact keys (see messages SYGNED_ENCRYPTED.txt).
    return {
      'em': internal['encrypted_message'],
      'pa': internal['password_algorithm'],
      'it': internal['iterations'],
      'tr': internal['transformation'],
      'ka': internal['key_algorithm'],
      'tv': internal['tk_version'],
      'kl': internal['output_key_length_bit'],
      'ec': internal['encoding'],
    };
  }

  /// Accepts Jackson long names or compact `em`/`pa` keys from blockchain payloads.
  static Map<String, dynamic> fromWireEncMessage(Map<String, dynamic> wire) {
    if (wire.containsKey('em')) {
      return {
        'encrypted_message': wire['em'],
        'password_algorithm': wire['pa'],
        'iterations': wire['it'],
        'transformation': wire['tr'],
        'key_algorithm': wire['ka'],
        'tk_version': wire['tv'],
        'output_key_length_bit': wire['kl'],
        'encoding': wire['ec'],
        if (wire['salt'] != null) 'salt': wire['salt'],
        if (wire['iv'] != null) 'iv': wire['iv'],
        if (wire['scope'] != null) 'scope': wire['scope'],
      };
    }
    return {
      'encrypted_message': wire['encrypted_message'],
      'password_algorithm':
          wire['password_hash_algorithm'] ?? wire['password_algorithm'],
      'iterations': wire['iterations'],
      'transformation': wire['transformation'],
      'key_algorithm': wire['key_spec_algorithm'] ?? wire['key_algorithm'],
      'tk_version': wire['tk_version'],
      'output_key_length_bit': wire['output_key_length_bit'],
      'encoding': wire['encoding'],
      if (wire['salt'] != null) 'salt': wire['salt'],
      if (wire['iv'] != null) 'iv': wire['iv'],
      if (wire['scope'] != null) 'scope': wire['scope'],
    };
  }

  /// RSChat v0_1_a: AES-CBC with PBKDF2 salt = [scope] (`TOPIC_MESSAGE`, …).
  static Map<String, dynamic> encryptWithPassword({
    required String password,
    required Object plaintextObject,
    required String scope,
  }) {
    final plaintext = TkmCanonicalJson.encode(plaintextObject);
    final key = _deriveScopeKeyCached(
      password: password,
      salt: scope,
      iterations: _iterations,
      keyLengthBits: 256,
    );
    final iv = _randomBytes(16);
    final padded = _pkcs7Pad(Uint8List.fromList(utf8.encode(plaintext)), 16);
    final cipher = CBCBlockCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(key), iv));
    final cipherBytes = Uint8List(padded.length);
    var offset = 0;
    while (offset < padded.length) {
      offset += cipher.processBlock(padded, offset, cipherBytes, offset);
    }

    return {
      'encrypted_message': [
        TkmBase64Url.encode(iv),
        TkmBase64Url.encode(cipherBytes),
      ],
      'password_algorithm': _wirePasswordAlgorithm,
      'iterations': _iterations,
      'transformation': 'AES/CBC/PKCS5Padding',
      'key_algorithm': _wireKeyAlgorithm,
      'tk_version': 'v0_1_a',
      'output_key_length_bit': 256,
      'encoding': _wireEncoding,
      'scope': scope,
    };
  }

  static String decryptWithPassword({
    required String password,
    required Map<String, dynamic> encMessage,
    required String scope,
  }) {
    final internal = fromWireEncMessage(encMessage);
    final encScope = internal['scope'] as String?;
    if (encScope != null && encScope != scope) {
      throw StateError('Encryption scope mismatch');
    }
    final chunks = (internal['encrypted_message'] as List)
        .map((e) => e.toString())
        .toList();

    if (_isRschatScopeCbcWire(internal, chunks)) {
      return _decryptRschatScopeCbc(
        password: password,
        scope: scope,
        internal: internal,
        chunks: chunks,
      );
    }
    return _decryptLegacyEmbeddedCbc(
      password: password,
      internal: internal,
      chunks: chunks,
    );
  }

  static bool _isRschatScopeCbcWire(
    Map<String, dynamic> internal,
    List<String> chunks,
  ) {
    if (chunks.length != 2) return false;
    final transformation = internal['transformation'] as String? ?? '';
    if (transformation.contains('GCM')) return false;
    return true;
  }

  static String _decryptRschatScopeCbc({
    required String password,
    required String scope,
    required Map<String, dynamic> internal,
    required List<String> chunks,
  }) {
    final key = _deriveScopeKeyCached(
      password: password,
      salt: scope,
      iterations: _iterationsFromWire(internal),
      keyLengthBits: internal['output_key_length_bit'] as int? ?? 256,
    );
    final iv = TkmBase64Url.decodeFlexible(chunks[0]);
    final cipherBytes = TkmBase64Url.decodeFlexible(chunks[1]);
    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), iv));
    final padded = Uint8List(cipherBytes.length);
    var offset = 0;
    while (offset < cipherBytes.length) {
      offset += cipher.processBlock(cipherBytes, offset, padded, offset);
    }
    return utf8.decode(_pkcs7Unpad(padded));
  }

  /// Legacy blockchain-style payload: random salt + IV embedded in `em` chunks.
  static String _decryptLegacyEmbeddedCbc({
    required String password,
    required Map<String, dynamic> internal,
    required List<String> chunks,
  }) {
    final Uint8List salt;
    final Uint8List iv;
    final Uint8List cipherBytes;
    if (internal['salt'] != null && internal['iv'] != null) {
      salt = TkmBase64Url.decode(internal['salt'] as String);
      iv = TkmBase64Url.decode(internal['iv'] as String);
      final cipherB64 = chunks.join().replaceAll('.', '=');
      cipherBytes = base64Url.decode(cipherB64);
    } else {
      final cipherB64 = chunks.join().replaceAll('.', '=');
      final payload = base64Url.decode(cipherB64);
      if (payload.length < 32) {
        throw StateError('Encrypted payload too short');
      }
      salt = Uint8List.sublistView(payload, 0, 16);
      iv = Uint8List.sublistView(payload, 16, 32);
      cipherBytes = Uint8List.sublistView(payload, 32);
    }

    final key = _deriveKeyLegacy(
      password,
      salt,
      iterations: _iterationsFromWire(internal),
    );
    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), iv));
    final padded = Uint8List(cipherBytes.length);
    var offset = 0;
    while (offset < cipherBytes.length) {
      offset += cipher.processBlock(cipherBytes, offset, padded, offset);
    }
    return utf8.decode(_pkcs7Unpad(padded));
  }

  static Map<String, dynamic> encryptTopicTitle(
    Map<String, dynamic> topicTitleKey,
    String symmetricKey,
  ) =>
      encryptWithPassword(
        password: symmetricKey,
        plaintextObject: topicTitleKey,
        scope: _scopeTopicCreation,
      );

  static Map<String, dynamic> encryptMessageContent(
    Map<String, dynamic> messageContent,
    String symmetricKey,
  ) =>
      encryptWithPassword(
        password: symmetricKey,
        plaintextObject: messageContent,
        scope: _scopeTopicMessage,
      );

  static Map<String, dynamic> decryptMessageContent(
    Map<String, dynamic> encMessage,
    String symmetricKey,
  ) {
    final json = decryptWithPassword(
      password: symmetricKey,
      encMessage: encMessage,
      scope: _scopeTopicMessage,
    );
    return jsonDecode(json) as Map<String, dynamic>;
  }

  static Uint8List _deriveKeyLegacy(
    String password,
    Uint8List salt, {
    int? iterations,
  }) {
    final it = iterations ?? _iterations;
    final derivator = PBKDF2KeyDerivator(HMac(SHA512Digest(), 64))
      ..init(Pbkdf2Parameters(salt, it, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  static Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padLength = blockSize - (data.length % blockSize);
    final padded = Uint8List(data.length + padLength);
    padded.setRange(0, data.length, data);
    for (var i = data.length; i < padded.length; i++) {
      padded[i] = padLength;
    }
    return padded;
  }

  static Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) {
      throw StateError('Cannot unpad empty ciphertext');
    }
    final padLength = data.last;
    if (padLength > data.length || padLength > 16) {
      throw StateError('Invalid PKCS7 padding');
    }
    for (var i = data.length - padLength; i < data.length; i++) {
      if (data[i] != padLength) {
        throw StateError('Invalid PKCS7 padding bytes');
      }
    }
    return Uint8List.sublistView(data, 0, data.length - padLength);
  }

  static int _iterationsFromWire(Map<String, dynamic> internal) {
    final raw = internal['iterations'];
    if (raw is int && raw > 0) return raw;
    if (raw is num && raw.toInt() > 0) return raw.toInt();
    return _iterations;
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }
}

class _DeriveScopeKeysParams {
  const _DeriveScopeKeysParams({
    required this.password,
    required this.scopes,
    required this.iterations,
    required this.keyLengthBits,
  });

  final String password;
  final List<String> scopes;
  final int iterations;
  final int keyLengthBits;
}

List<Uint8List> _deriveScopeKeysBlocking(_DeriveScopeKeysParams params) {
  return [
    for (final scope in params.scopes)
      TkmPbkdf2.deriveKey(
        password: params.password,
        salt: scope,
        iterations: params.iterations,
        keyLengthBits: params.keyLengthBits,
      ),
  ];
}
