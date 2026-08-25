import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_encryption.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_rsa.dart';
import 'package:takamaka_sdk_wrap/models/chat/tkm_chat_profile_models.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_base64_url.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_canonical_json.dart';

/// AES-256-GCM seal/unseal and RSA grants for the user-profile channel.
///
/// Unlike message encryption, the profile key is **32 raw bytes** — no PBKDF2.
abstract final class TkmChatProfileCrypto {
  static const int keyByteLength = 32;
  static const int ivByteLength = 12;
  static const int tagBitLength = 128;

  static final FortunaRandom _secureRandom = FortunaRandom()
    ..seed(KeyParameter(Uint8List.fromList(
      List.generate(32, (_) => Random.secure().nextInt(256)),
    )));

  /// Fresh 32-byte key, returned as Base64URL text (wire grant plaintext).
  static String generateProfileKeyText() {
    final bytes = Uint8List(keyByteLength);
    for (var i = 0; i < keyByteLength; i++) {
      bytes[i] = _secureRandom.nextUint8();
    }
    return TkmBase64Url.encode(bytes);
  }

  static Uint8List profileKeyBytesFromText(String profileKeyText) {
    final bytes = TkmBase64Url.decodeFlexible(profileKeyText);
    if (bytes.length != keyByteLength) {
      throw ArgumentError.value(
        profileKeyText,
        'profileKeyText',
        'Profile key must decode to $keyByteLength bytes',
      );
    }
    return bytes;
  }

  /// Seals [card] under a new or provided profile key.
  ///
  /// [keyEpoch] must be the server nonce `timestamp` (not the client clock).
  static ({TkmEncryptedProfile encrypted, String profileKeyText}) sealCard({
    required TkmProfileCard card,
    required int keyEpoch,
    String? profileKeyText,
  }) {
    final keyText = profileKeyText ?? generateProfileKeyText();
    final keyBytes = profileKeyBytesFromText(keyText);
    final plaintext = Uint8List.fromList(
      utf8.encode(TkmCanonicalJson.encode(card.toJson())),
    );
    final iv = _randomBytes(ivByteLength);
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      true,
      AEADParameters(KeyParameter(keyBytes), tagBitLength, iv, Uint8List(0)),
    );
    final ciphertextAndTag = cipher.process(plaintext);
    final blobBytes = Uint8List(iv.length + ciphertextAndTag.length)
      ..setRange(0, iv.length, iv)
      ..setRange(iv.length, iv.length + ciphertextAndTag.length, ciphertextAndTag);
    final blob = TkmBase64Url.encode(blobBytes);
    final blobHash = sha3Hex(blobBytes);
    return (
      encrypted: TkmEncryptedProfile(
        keyEpoch: keyEpoch,
        blob: blob,
        blobHash: blobHash,
      ),
      profileKeyText: keyText,
    );
  }

  static TkmProfileCard unsealCard({
    required TkmEncryptedProfile encrypted,
    required String profileKeyText,
  }) {
    final keyBytes = profileKeyBytesFromText(profileKeyText);
    final blobBytes = TkmBase64Url.decodeFlexible(encrypted.blob);
    if (blobBytes.length <= ivByteLength) {
      throw StateError('Profile blob too short');
    }
    final expectedHash = sha3Hex(blobBytes);
    if (encrypted.blobHash.isNotEmpty &&
        encrypted.blobHash.toLowerCase() != expectedHash) {
      throw StateError(
        'Profile blob_hash mismatch: expected ${encrypted.blobHash}, '
        'got $expectedHash',
      );
    }
    final iv = blobBytes.sublist(0, ivByteLength);
    final ciphertextAndTag = blobBytes.sublist(ivByteLength);
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      false,
      AEADParameters(KeyParameter(keyBytes), tagBitLength, iv, Uint8List(0)),
    );
    final plaintext = cipher.process(ciphertextAndTag);
    final decoded = jsonDecode(utf8.decode(plaintext));
    if (decoded is! Map) {
      throw StateError('Profile card plaintext is not a JSON object');
    }
    final card = TkmProfileCard.fromJson(Map<String, dynamic>.from(decoded));
    if (card.payloadVersion != TkmChatProfileConstants.payloadVersion10) {
      throw StateError(
        'Unsupported profile payload_version: ${card.payloadVersion}',
      );
    }
    return card;
  }

  /// Builds one grant: RSA wraps the **Base64URL text** of the profile key.
  static TkmProfileGrant buildGrant({
    required String granteeIdentityKey,
    required int keyEpoch,
    required String profileKeyText,
    required String peerEncryptionPublicKey,
  }) {
    final rsaPublic =
        TkmChatRsaKeyPair.decodePublicKey(peerEncryptionPublicKey);
    return TkmProfileGrant(
      grantee: granteeIdentityKey,
      keyEpoch: keyEpoch,
      encKeyHash: TkmChatEncryption.hashSha3_256B64Url(peerEncryptionPublicKey),
      encKey: TkmChatRsaKeyPair.encryptWithPublicKey(rsaPublic, profileKeyText),
    );
  }

  /// Unwraps a grant with the local RSA private key → profile key text.
  static String unwrapGrant({
    required TkmProfileGrant grant,
    required TkmChatRsaKeyPair rsaKeyPair,
    required String ownEncryptionPublicKey,
  }) {
    final expectedHash =
        TkmChatEncryption.hashSha3_256B64Url(ownEncryptionPublicKey);
    if (grant.encKeyHash.isNotEmpty && grant.encKeyHash != expectedHash) {
      throw StateError('Profile grant enc_key_hash does not match local key');
    }
    return rsaKeyPair.decrypt(grant.encKey);
  }

  static String sha3Hex(Uint8List data) {
    final digest = SHA3Digest(256);
    return digest
        .process(data)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// NFC + code-point length clamp (characters, not UTF-16 units).
  static String? normalizeField(String? value, int maxChars) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final nfc = trimmed; // Dart strings are already NFC-capable; count runes.
    final runes = nfc.runes.toList();
    if (runes.length <= maxChars) return String.fromCharCodes(runes);
    return String.fromCharCodes(runes.take(maxChars));
  }

  /// Strip C0/C1 controls and bidi overrides before display (registry §4.5).
  static String sanitizeForDisplay(String? value, {int? maxChars}) {
    if (value == null || value.isEmpty) return '';
    final buf = StringBuffer();
    for (final rune in value.runes) {
      if (rune <= 0x1F || (rune >= 0x7F && rune <= 0x9F)) continue;
      if (rune >= 0x202A && rune <= 0x202E) continue;
      if (rune >= 0x2066 && rune <= 0x2069) continue;
      buf.writeCharCode(rune);
    }
    var out = buf.toString();
    if (maxChars != null && out.runes.length > maxChars) {
      out = String.fromCharCodes(out.runes.take(maxChars));
    }
    return out;
  }

  static Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextUint8();
    }
    return bytes;
  }
}
