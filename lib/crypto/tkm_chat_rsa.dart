import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/export.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_seeded_random.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_base64_url.dart';

/// RSA-4096 key material for chat encryption invites.
class TkmChatRsaKeyPair {
  TkmChatRsaKeyPair({
    required this.publicKeyUrl64,
    required this.privateKey,
    required this.publicKey,
  });

  final String publicKeyUrl64;
  final RSAPrivateKey privateKey;
  final RSAPublicKey publicKey;

  /// RSA-4096 generation is CPU-heavy; run off the UI isolate when possible.
  static Future<TkmChatRsaKeyPair> generate() async {
    if (kIsWeb) {
      return _generateBlocking();
    }
    return compute(_generateInIsolate, null);
  }

  /// Deterministic RSA-4096 derived from wallet seed + sign key index.
  ///
  /// Same wallet identity always yields the same chat encryption key pair,
  /// so conversation invites remain decryptable after reinstall.
  static Future<TkmChatRsaKeyPair> fromWalletSeed(
    String walletSeed, {
    int signKeyIndex = 0,
  }) async {
    final params = _WalletDerivedRsaParams(
      walletSeed: walletSeed,
      signKeyIndex: signKeyIndex,
    );
    if (kIsWeb) {
      return _generateFromWalletSeedBlocking(params);
    }
    return compute(_generateFromWalletSeedBlocking, params);
  }

  /// JSON map for secure local persistence (same key across app restarts).
  Map<String, dynamic> toStorageJson() => {
        'publicKeyUrl64': publicKeyUrl64,
        'modulus': publicKey.modulus!.toString(),
        'privateExponent': privateKey.privateExponent!.toString(),
        'publicExponent': publicKey.exponent!.toString(),
        'p': privateKey.p!.toString(),
        'q': privateKey.q!.toString(),
      };

  static TkmChatRsaKeyPair? fromStorageJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final publicKeyUrl64 = json['publicKeyUrl64'] as String?;
    final modulusRaw = json['modulus'] as String?;
    final privateExponentRaw = json['privateExponent'] as String?;
    final publicExponentRaw = json['publicExponent'] as String?;
    if (publicKeyUrl64 == null ||
        modulusRaw == null ||
        privateExponentRaw == null ||
        publicExponentRaw == null) {
      return null;
    }
    try {
      final modulus = BigInt.parse(modulusRaw);
      final privateExponent = BigInt.parse(privateExponentRaw);
      final publicExponent = BigInt.parse(publicExponentRaw);
      final pRaw = json['p'] as String?;
      final qRaw = json['q'] as String?;
      final publicKey = RSAPublicKey(modulus, publicExponent);
      final privateKey = (pRaw != null && qRaw != null)
          ? RSAPrivateKey(
              modulus,
              privateExponent,
              BigInt.parse(pRaw),
              BigInt.parse(qRaw),
            )
          : RSAPrivateKey(
              modulus,
              privateExponent,
              BigInt.one,
              BigInt.one,
            );
      return TkmChatRsaKeyPair(
        publicKeyUrl64: publicKeyUrl64,
        privateKey: privateKey,
        publicKey: publicKey,
      );
    } catch (_) {
      return null;
    }
  }

  String encrypt(String plaintext) =>
      encryptWithPublicKey(publicKey, plaintext);

  static String encryptWithPublicKey(
    RSAPublicKey publicKey,
    String plaintext,
  ) {
    final engine = OAEPEncoding.withSHA256(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    final input = Uint8List.fromList(utf8.encode(plaintext));
    return TkmBase64Url.encode(engine.process(input));
  }

  String decrypt(String ciphertext) {
    final input = TkmBase64Url.decodeFlexible(ciphertext);
    try {
      return _decryptOaep(input, OAEPEncoding.withSHA256(RSAEngine()));
    } catch (_) {
      // Legacy invites may have been encrypted with OAEP-SHA1.
      return _decryptOaep(input, OAEPEncoding(RSAEngine()));
    }
  }

  /// RSA-4096 OAEP decrypt is CPU-heavy in pure Dart (~100ms+ on mobile);
  /// run it off the UI isolate when possible.
  Future<String> decryptAsync(String ciphertext) {
    final p = privateKey.p;
    final q = privateKey.q;
    if (kIsWeb || p == null || q == null) {
      return Future<String>.value(decrypt(ciphertext));
    }
    return compute(
      _rsaDecryptBlocking,
      _RsaDecryptParams(
        modulus: privateKey.modulus!,
        privateExponent: privateKey.privateExponent!,
        p: p,
        q: q,
        ciphertext: ciphertext,
      ),
    );
  }

  String _decryptOaep(Uint8List input, OAEPEncoding engine) {
    engine.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    try {
      return utf8.decode(engine.process(input));
    } on FormatException {
      throw StateError('RSA OAEP decrypt produced invalid UTF-8 (wrong key?)');
    }
  }

  static RSAPublicKey decodePublicKey(String publicKeyUrl64) {
    final bytes = TkmBase64Url.decode(publicKeyUrl64);
    return _decodePublicKeySpki(bytes);
  }

  static Uint8List _seed(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Uint8List _encodePublicKeySpki(RSAPublicKey publicKey) {
    final algorithmSeq = ASN1Sequence()
      ..add(ASN1ObjectIdentifier.fromComponentString('1.2.840.113549.1.1.1'))
      ..add(ASN1Null());
    final publicKeySeq = ASN1Sequence()
      ..add(ASN1Integer(publicKey.modulus!))
      ..add(ASN1Integer(publicKey.exponent!));
    final publicKeyBitString = ASN1BitString(
      Uint8List.fromList(publicKeySeq.encodedBytes),
    );
    final topLevel = ASN1Sequence()
      ..add(algorithmSeq)
      ..add(publicKeyBitString);
    return topLevel.encodedBytes;
  }

  static RSAPublicKey _decodePublicKeySpki(Uint8List bytes) {
    final topLevel = ASN1Parser(bytes).nextObject() as ASN1Sequence;
    final publicKeyBitString = topLevel.elements![1] as ASN1BitString;
    final publicKeySeq = ASN1Parser(publicKeyBitString.contentBytes())
        .nextObject() as ASN1Sequence;
    final modulus =
        (publicKeySeq.elements![0] as ASN1Integer).valueAsBigInteger;
    final exponent =
        (publicKeySeq.elements![1] as ASN1Integer).valueAsBigInteger;
    return RSAPublicKey(modulus, exponent);
  }
}

Future<TkmChatRsaKeyPair> _generateInIsolate(void _) => _generateBlocking();

class _RsaDecryptParams {
  const _RsaDecryptParams({
    required this.modulus,
    required this.privateExponent,
    required this.p,
    required this.q,
    required this.ciphertext,
  });

  final BigInt modulus;
  final BigInt privateExponent;
  final BigInt p;
  final BigInt q;
  final String ciphertext;
}

String _rsaDecryptBlocking(_RsaDecryptParams params) {
  final privateKey = RSAPrivateKey(
    params.modulus,
    params.privateExponent,
    params.p,
    params.q,
  );
  final input = TkmBase64Url.decodeFlexible(params.ciphertext);

  String decryptWith(OAEPEncoding engine) {
    engine.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
    try {
      return utf8.decode(engine.process(input));
    } on FormatException {
      throw StateError('RSA OAEP decrypt produced invalid UTF-8 (wrong key?)');
    }
  }

  try {
    return decryptWith(OAEPEncoding.withSHA256(RSAEngine()));
  } catch (_) {
    // Legacy invites may have been encrypted with OAEP-SHA1.
    return decryptWith(OAEPEncoding(RSAEngine()));
  }
}

class _WalletDerivedRsaParams {
  const _WalletDerivedRsaParams({
    required this.walletSeed,
    required this.signKeyIndex,
  });

  final String walletSeed;
  final int signKeyIndex;
}

Future<TkmChatRsaKeyPair> _generateFromWalletSeedBlocking(
  _WalletDerivedRsaParams params,
) async {
  // Matches wallet-core Rsa4096Keystore: scope __WKCH__, keyNumber index + 1.
  final secureRandom = TkmSeededRandom(
    walletSeed: params.walletSeed,
    scope: TkmWalletKeyScopes.walletKeyChain,
    keyNumber: params.signKeyIndex + 1,
  );
  final keyGen = RSAKeyGenerator()
    ..init(ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.from(65537), 4096, 64),
      secureRandom,
    ));
  final pair = keyGen.generateKeyPair();
  final publicKey = pair.publicKey as RSAPublicKey;
  final privateKey = pair.privateKey as RSAPrivateKey;
  final encodedPublic = TkmChatRsaKeyPair._encodePublicKeySpki(publicKey);
  return TkmChatRsaKeyPair(
    publicKeyUrl64: TkmBase64Url.encode(encodedPublic),
    privateKey: privateKey,
    publicKey: publicKey,
  );
}

Future<TkmChatRsaKeyPair> _generateBlocking() async {
  final secureRandom = FortunaRandom()
    ..seed(KeyParameter(TkmChatRsaKeyPair._seed(32)));
  final keyGen = RSAKeyGenerator()
    ..init(ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.from(65537), 4096, 64),
      secureRandom,
    ));
  final pair = keyGen.generateKeyPair();
  final publicKey = pair.publicKey as RSAPublicKey;
  final privateKey = pair.privateKey as RSAPrivateKey;
  final encodedPublic = TkmChatRsaKeyPair._encodePublicKeySpki(publicKey);
  return TkmChatRsaKeyPair(
    publicKeyUrl64: TkmBase64Url.encode(encodedPublic),
    privateKey: privateKey,
    publicKey: publicKey,
  );
}
