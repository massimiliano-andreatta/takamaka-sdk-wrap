import 'package:cryptography/cryptography.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_rsa.dart';

/// Signing (Ed25519) + encryption (RSA-4096) keys for rschat.
class ChatKeyMaterial {
  ChatKeyMaterial({
    required this.signKeyPair,
    required this.rsaKeyPair,
    this.signKeyIndex = 0,
  });

  final SimpleKeyPair signKeyPair;
  final TkmChatRsaKeyPair rsaKeyPair;
  final int signKeyIndex;

  String get rsaPublicKeyUrl64 => rsaKeyPair.publicKeyUrl64;

  static Future<ChatKeyMaterial> fromWalletSeed(
    String seed, {
    int signKeyIndex = 0,
    TkmChatRsaKeyPair? rsaKeyPair,
  }) async {
    final signKeyPair =
        await WalletUtils.getNewKeypairED25519(seed, index: signKeyIndex);
    final resolvedRsa = rsaKeyPair ?? await TkmChatRsaKeyPair.generate();
    return ChatKeyMaterial(
      signKeyPair: signKeyPair,
      rsaKeyPair: resolvedRsa,
      signKeyIndex: signKeyIndex,
    );
  }
}
