import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_base64_url.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_canonical_json.dart';

/// Ed25519 signing for rschat signed envelopes (raw UTF-8 canonical JSON bytes).
abstract final class TkmChatSigning {
  static const String signatureType = 'Ed25519BC';
  static final Ed25519 _algorithm = Ed25519();

  static Future<String> publicKeyUrl64(SimpleKeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey();
    return TkmBase64Url.encodeEd25519PublicKey(
      Uint8List.fromList(publicKey.bytes),
    );
  }

  static Future<String> signCanonicalJson(
    SimpleKeyPair keyPair,
    Object signedContent,
  ) async {
    final canonical = TkmCanonicalJson.encode(signedContent);
    return signUtf8Message(keyPair, canonical);
  }

  /// Signs [signedContent] with BouncyCastle `Strings.toByteArray` encoding
  /// (DR-027 / rsclient `JavaCompatibleSigning`). ASCII canonical JSON matches
  /// UTF-8; required for any non-ASCII cleartext in the sign unit.
  static Future<String> signCanonicalJsonJavaCompatible(
    SimpleKeyPair keyPair,
    Object signedContent,
  ) async {
    final canonical = TkmCanonicalJson.encode(signedContent);
    return signBytes(keyPair, javaToByteArray(canonical));
  }

  /// BouncyCastle `Strings.toByteArray`: one byte per UTF-16 code unit, low 8 bits.
  static Uint8List javaToByteArray(String message) {
    final codeUnits = message.codeUnits;
    final bytes = Uint8List(codeUnits.length);
    for (var i = 0; i < codeUnits.length; i++) {
      bytes[i] = codeUnits[i] & 0xFF;
    }
    return bytes;
  }

  static Future<String> signUtf8Message(
    SimpleKeyPair keyPair,
    String message,
  ) async {
    return signBytes(keyPair, Uint8List.fromList(utf8.encode(message)));
  }

  static Future<String> signBytes(
    SimpleKeyPair keyPair,
    Uint8List messageBytes,
  ) async {
    final signature = await _algorithm.sign(
      messageBytes,
      keyPair: keyPair,
    );
    return TkmBase64Url.encode(Uint8List.fromList(signature.bytes));
  }

  static Future<bool> verifyUtf8Message({
    required String publicKeyUrl64,
    required String signatureUrl64,
    required String message,
  }) {
    return verifyBytes(
      publicKeyUrl64: publicKeyUrl64,
      signatureUrl64: signatureUrl64,
      messageBytes: Uint8List.fromList(utf8.encode(message)),
    );
  }

  static Future<bool> verifyCanonicalJson({
    required String publicKeyUrl64,
    required String signatureUrl64,
    required Object signedContent,
  }) {
    return verifyUtf8Message(
      publicKeyUrl64: publicKeyUrl64,
      signatureUrl64: signatureUrl64,
      message: TkmCanonicalJson.encode(signedContent),
    );
  }

  static Future<bool> verifyCanonicalJsonJavaCompatible({
    required String publicKeyUrl64,
    required String signatureUrl64,
    required Object signedContent,
  }) {
    final canonical = TkmCanonicalJson.encode(signedContent);
    return verifyBytes(
      publicKeyUrl64: publicKeyUrl64,
      signatureUrl64: signatureUrl64,
      messageBytes: javaToByteArray(canonical),
    );
  }

  static Future<bool> verifyBytes({
    required String publicKeyUrl64,
    required String signatureUrl64,
    required Uint8List messageBytes,
  }) async {
    final publicKeyBytes = TkmBase64Url.decode(publicKeyUrl64);
    final signatureBytes = TkmBase64Url.decode(signatureUrl64);
    final publicKey = SimplePublicKey(
      publicKeyBytes,
      type: KeyPairType.ed25519,
    );
    return _algorithm.verify(
      messageBytes,
      signature: Signature(
        signatureBytes,
        publicKey: publicKey,
      ),
    );
  }

  static Map<String, dynamic> signedEnvelope({
    required String from,
    required String signature,
    required String messageType,
    required Map<String, dynamic> signedContentField,
    required String signedContentKey,
  }) {
    return {
      'from': from,
      'signature': signature,
      'message_type': messageType,
      'signature_type': signatureType,
      signedContentKey: signedContentField,
    };
  }
}
