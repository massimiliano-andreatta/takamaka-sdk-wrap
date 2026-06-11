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

  static Future<String> signUtf8Message(
    SimpleKeyPair keyPair,
    String message,
  ) async {
    final messageBytes = utf8.encode(message);
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
  }) async {
    final publicKeyBytes = TkmBase64Url.decode(publicKeyUrl64);
    final signatureBytes = TkmBase64Url.decode(signatureUrl64);
    final messageBytes = utf8.encode(message);
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
