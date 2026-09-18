import 'package:cryptography/cryptography.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_rsa.dart';

/// Signing (Ed25519) + encryption (RSA-4096) keys for rschat.
class ChatKeyMaterial {
  ChatKeyMaterial({
    required this.signKeyPair,
    required this.rsaKeyPair,
    this.rsaKeyFallbacks = const [],
    this.signKeyIndex = 0,
  });

  final SimpleKeyPair signKeyPair;
  final TkmChatRsaKeyPair rsaKeyPair;
  final List<TkmChatRsaKeyPair> rsaKeyFallbacks;
  final int signKeyIndex;

  String get rsaPublicKeyUrl64 => rsaKeyPair.publicKeyUrl64;

  /// Primary RSA key plus any wallet-derived or legacy fallbacks (deduped).
  List<TkmChatRsaKeyPair> get rsaKeyCandidates {
    final seen = <String>{};
    final out = <TkmChatRsaKeyPair>[];
    for (final pair in [rsaKeyPair, ...rsaKeyFallbacks]) {
      if (seen.add(pair.publicKeyUrl64)) {
        out.add(pair);
      }
    }
    return out;
  }

  static Future<ChatKeyMaterial> fromWalletSeed(
    String seed, {
    int signKeyIndex = 0,
    TkmChatRsaKeyPair? rsaKeyPair,
    List<TkmChatRsaKeyPair> rsaKeyFallbacks = const [],
  }) async {
    final signKeyPair =
        await WalletUtils.getNewKeypairED25519(seed, index: signKeyIndex);
    final resolvedRsa = rsaKeyPair ?? await TkmChatRsaKeyPair.generate();
    return ChatKeyMaterial(
      signKeyPair: signKeyPair,
      rsaKeyPair: resolvedRsa,
      rsaKeyFallbacks: rsaKeyFallbacks,
      signKeyIndex: signKeyIndex,
    );
  }

  /// Replaces the active RSA key after a successful invite decrypt fallback.
  ChatKeyMaterial withPromotedRsaKey(TkmChatRsaKeyPair promoted) {
    final previous = rsaKeyPair;
    final nextFallbacks = <TkmChatRsaKeyPair>[
      ...rsaKeyFallbacks,
      if (previous.publicKeyUrl64 != promoted.publicKeyUrl64) previous,
    ];
    return ChatKeyMaterial(
      signKeyPair: signKeyPair,
      rsaKeyPair: promoted,
      rsaKeyFallbacks: nextFallbacks,
      signKeyIndex: signKeyIndex,
    );
  }
}
