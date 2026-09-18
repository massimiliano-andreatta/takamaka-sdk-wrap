import 'package:cryptography/cryptography.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';

/// Fixtures from [docs/SERVER_API_GUIDE.pdf] (CrossPlatformIntegrationTest vectors).
abstract final class ChatApiGuideFixtures {
  /// 25-word mnemonic used in the guide for Ed25519 key index 4.
  static const List<String> guideMnemonic = [
    'sample',
    'half',
    'mammal',
    'radar',
    'hold',
    'fit',
    'era',
    'dilemma',
    'manage',
    'movie',
    'razor',
    'saddle',
    'point',
    'dial',
    'sadness',
    'north',
    'item',
    'naive',
    'gate',
    'hockey',
    'sample',
    'script',
    'embark',
    'purse',
    'myth',
  ];

  static const int guideSignKeyIndex = 4;

  /// Expected Ed25519 public key (base64url, 44 chars + trailing `.`).
  static const String guidePublicKeyUrl64 =
      'el3xvxJnLv9S9aWD0ei3g96YGOAvdYW_yn5z1eIvCDc.';

  /// Canonical JSON bytes used in testKnownSignatureVector.
  static const String guideSignatureMessage =
      '{"action":"test","timestamp":1706000000000}';

  /// Expected signature for [guideSignatureMessage] with [guideMnemonic] index 4.
  static const String guideSignatureUrl64 =
      'sztKewymT5AwihP5yvWfMEQuD6Fs4AQFFIVhGkyYppxLIePioAG3egyGhog4Uh9YsxxZG5kWQ0s_UT-ESMo-DQ..';

  /// Nonce example from guide §5.2 (registeruser).
  static Map<String, dynamic> guideNonceResponse() => {
        'nonce': '8c83f0e0-2b2a-4f57-a9d4-7f7b80a31a99',
        'timestamp': 1706000000000,
        'liveness': 900000,
      };

  static Future<SimpleKeyPair> guideSignKeyPair() async {
    final seed = await WalletUtils.generateSeedPWH(guideMnemonic);
    return WalletUtils.getNewKeypairED25519(seed, index: guideSignKeyIndex);
  }

  static Future<ChatKeyMaterial> guideKeyMaterial() async {
    final seed = await WalletUtils.generateSeedPWH(guideMnemonic);
    return ChatKeyMaterial.fromWalletSeed(seed, signKeyIndex: guideSignKeyIndex);
  }
}
