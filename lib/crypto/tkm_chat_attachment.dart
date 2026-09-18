import 'dart:convert';
import 'dart:typed_data';

import 'package:takamaka_sdk_wrap/constants/chat_message_types.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_stream_encryption.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';
import 'package:takamaka_sdk_wrap/models/chat/stream_encrypted_descriptor.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_base64_url.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_canonical_json.dart';

/// Inline attachment threshold (~48 KB plaintext, safe under message blob limit).
const int kChatAttachmentInlineMaxBytes = 48 * 1024;

/// Default upload chunk when `serverinfo` was not probed (conservative 4 KB).
/// Prefer [TkmChatClientApi.negotiatedUploadChunkBytes] after connect.
const int kChatAttachmentUploadChunkSize = 4096;

/// Helpers for rschat attachment encryption, wire placeholders, and signed requests.
abstract final class TkmChatAttachment {
  static String computePlaintextHashUrl64(Uint8List data) {
    return TkmChatStreamEncryption.computePlaintextHashUrl64(data);
  }

  static Future<String> computePlaintextHashUrl64Async(Uint8List data) {
    return TkmChatStreamEncryption.computePlaintextHashUrl64Async(data);
  }

  static EncryptedAttachmentResult encryptForUpload({
    required String symmetricKey,
    required String conversationHash,
    required Uint8List plaintext,
  }) {
    final result = TkmChatStreamEncryption.encrypt(
      password: symmetricKey,
      scope: conversationHash,
      plaintext: plaintext,
    );
    return EncryptedAttachmentResult(
      encryptedData: result.encryptedData,
      plaintextHashHex: result.plaintextHashHex,
      plaintextHashUrl64: _url64FromHexHash(result.plaintextHashHex),
      descriptor: result.descriptor,
    );
  }

  /// Non-blocking encrypt (rsclient `encryptForUploadAsync`) for large files.
  static Future<EncryptedAttachmentResult> encryptForUploadAsync({
    required String symmetricKey,
    required String conversationHash,
    required Uint8List plaintext,
  }) async {
    final result = await TkmChatStreamEncryption.encryptAsync(
      password: symmetricKey,
      scope: conversationHash,
      plaintext: plaintext,
    );
    return EncryptedAttachmentResult(
      encryptedData: result.encryptedData,
      plaintextHashHex: result.plaintextHashHex,
      plaintextHashUrl64: _url64FromHexHash(result.plaintextHashHex),
      descriptor: result.descriptor,
    );
  }

  static String _url64FromHexHash(String hex) {
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      bytes[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return TkmBase64Url.encode(bytes);
  }

  static Uint8List decryptDownload({
    required String symmetricKey,
    required StreamEncryptedDescriptor descriptor,
    required Uint8List encryptedData,
    String? expectedPlaintextHashHex,
  }) {
    return TkmChatStreamEncryption.decrypt(
      password: symmetricKey,
      descriptor: descriptor,
      encryptedData: encryptedData,
      expectedPlaintextHashHex: expectedPlaintextHashHex,
    );
  }

  static Map<String, dynamic> buildInlinePlaceholder({
    required String mediaType,
    required Uint8List plaintext,
    String? fileName,
  }) {
    final preview = base64Encode(plaintext);
    final hashUrl64 = computePlaintextHashUrl64(plaintext);
    return {
      'media_type': mediaType,
      'size': plaintext.length,
      'unencrypted_content_hash': hashUrl64,
      'preview': preview,
      'is_the_object': true,
      if (fileName != null && fileName.isNotEmpty) 'file_name': fileName,
      'original_size': plaintext.length,
    };
  }

  static Map<String, dynamic> buildServerPlaceholder({
    required String mediaType,
    required EncryptedAttachmentResult encrypted,
    required int originalSize,
    String? fileName,
    String? previewBase64,
  }) {
    return {
      'media_type': mediaType,
      'size': encrypted.encryptedData.length,
      'unencrypted_content_hash': encrypted.plaintextHashUrl64,
      'encrypted_file_hash': encrypted.descriptor.encryptedContentHash,
      'sed': encrypted.descriptor.toJson(),
      'is_the_object': false,
      'original_size': originalSize,
      if (fileName != null && fileName.isNotEmpty) 'file_name': fileName,
      if (previewBase64 != null && previewBase64.isNotEmpty)
        'preview': previewBase64,
    };
  }

  static Future<Map<String, dynamic>> buildSignedUploadRequest({
    required ChatKeyMaterial keys,
    required String conversationHash,
    required EncryptedAttachmentResult encrypted,
  }) async {
    final uploadDescriptor = {
      'topic_title': conversationHash,
      'upload_content_id_hash': encrypted.descriptor.encryptedContentHash,
      'size': encrypted.encryptedData.length,
      'sed': encrypted.descriptor.toJson(),
    };
    final signature = await TkmChatSigning.signCanonicalJson(
      keys.signKeyPair,
      uploadDescriptor,
    );
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    return {
      'from': from,
      'signature': signature,
      'message_type': ChatMessageTypes.uploadRequest,
      'signature_type': TkmChatSigning.signatureType,
      'upload_descriptor': uploadDescriptor,
    };
  }

  static String? encryptedHashFromWire(Map<String, dynamic> map) {
    for (final key in [
      'encrypted_file_hash',
      'encryptedFileHash',
      'encrypted_hash',
    ]) {
      final value = _nonEmptyString(map[key]);
      if (value != null) return value;
    }
    final fromSed = sedFromWire(map)?.encryptedContentHash;
    if (fromSed != null && fromSed.trim().isNotEmpty) return fromSed.trim();
    return null;
  }

  static String? plaintextHashFromWire(Map<String, dynamic> map) {
    for (final key in [
      'unencrypted_content_hash',
      'unencryptedContentHash',
      'plaintext_hash',
    ]) {
      final value = _nonEmptyString(map[key]);
      if (value != null) return value;
    }
    return null;
  }

  static String? _nonEmptyString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static bool isInlineWireMap(Map<String, dynamic> map) {
    final flag = map['is_the_object'] ?? map['isTheObject'];
    if (flag == true || flag == 1) return true;
    if (flag is String) {
      final normalized = flag.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  static bool requiresServerDownload(Map<String, dynamic> map) {
    if (isInlineWireMap(map)) return false;
    final hash = encryptedHashFromWire(map);
    return hash != null && hash.isNotEmpty;
  }

  static StreamEncryptedDescriptor? sedFromWire(Map<String, dynamic> map) {
    final raw = map['sed'];
    if (raw is Map) {
      return StreamEncryptedDescriptor.fromJson(Map<String, dynamic>.from(raw));
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return StreamEncryptedDescriptor.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (_) {}
    }
    return null;
  }

  /// Full inline payload bytes (`is_the_object`) or orphan preview without blob id.
  ///
  /// Returns null for blob placeholders that only carry a thumbnail preview
  /// alongside [encrypted_file_hash].
  static Uint8List? inlineBytesFromWire(Map<String, dynamic> map) {
    final efh = encryptedHashFromWire(map);
    if (!isInlineWireMap(map) && efh != null && efh.isNotEmpty) {
      return null;
    }
    final preview = map['preview'] ??
        map['base64_encoded_media'] ??
        map['previewBase64'] ??
        map['content'];
    return decodeMediaBase64(preview);
  }

  /// Decodes attachment preview/inline payloads (STD base64 or Takamaka URL64).
  static Uint8List? decodeMediaBase64(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      return TkmBase64Url.decodeFlexible(raw);
    } catch (_) {
      try {
        // Some peers emit URL-safe alphabet with standard `=` padding.
        return Uint8List.fromList(
          base64Url.decode(raw.replaceAll('-', '+').replaceAll('_', '/')),
        );
      } catch (_) {
        return null;
      }
    }
  }

  /// True when the placeholder can be opened (inline bytes or server blob id).
  static bool isOpenableWireMap(Map<String, dynamic> map) {
    if (encryptedHashFromWire(map) != null) return true;
    final bytes = inlineBytesFromWire(map) ?? decodeMediaBase64(map['preview']);
    return bytes != null && bytes.isNotEmpty;
  }

  /// Flattens common wrapper shapes around a media placeholder.
  static Map<String, dynamic> normalizeWireMap(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    for (final key in [
      'placeholder',
      'media',
      'chat_media_placeholder',
      'attachment',
      'attached_medium',
    ]) {
      final nested = map[key];
      if (nested is Map) {
        return Map<String, dynamic>.from(nested);
      }
    }
    return map;
  }

  static List<Map<String, dynamic>> wireMapsFromDecrypted(
    Map<String, dynamic> decrypted,
  ) {
    final media = decrypted['attached_media'] ?? decrypted['attachedMedia'];
    if (media is! List) return const [];
    return media
        .whereType<Map>()
        .map(normalizeWireMap)
        .toList(growable: false);
  }

  /// Compact diagnostics for attach debugging (no payload bytes).
  static String wireSummary(Map<String, dynamic> wire) {
    String lenOf(Object? value) {
      if (value is String) return 'str(${value.length})';
      if (value is Map) return 'map(keys=${value.keys.toList()})';
      if (value is List) return 'list(${value.length})';
      if (value == null) return 'null';
      return value.runtimeType.toString();
    }

    final keys = wire.keys.toList()..sort();
    final parts = <String>[];
    for (final key in keys) {
      parts.add('$key=${lenOf(wire[key])}');
    }
    return parts.join(' ');
  }

  static String canonicalUploadDescriptorJson(Map<String, dynamic> upload) {
    return TkmCanonicalJson.encode(upload);
  }
}

class EncryptedAttachmentResult {
  const EncryptedAttachmentResult({
    required this.encryptedData,
    required this.plaintextHashHex,
    required this.plaintextHashUrl64,
    required this.descriptor,
  });

  final Uint8List encryptedData;
  final String plaintextHashHex;
  final String plaintextHashUrl64;
  final StreamEncryptedDescriptor descriptor;
}
