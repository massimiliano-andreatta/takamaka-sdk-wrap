import 'package:flutter_test/flutter_test.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/utils/tkm_canonical_json.dart';

void main() {
  test('canonical json orders keys', () {
    final canonical = TkmCanonicalJson.encode({
      'timestamp': 1706000000000,
      'action': 'test',
    });
    expect(canonical, '{"action":"test","timestamp":1706000000000}');
  });

  test('sign and verify round-trip', () async {
    final words = List.generate(25, (i) => 'word$i');
    final seed = await WalletUtils.generateSeedPWH(words);
    final keyPair = await WalletUtils.getNewKeypairED25519(seed, index: 4);
    const message = '{"action":"test","timestamp":1706000000000}';
    final signature = await TkmChatSigning.signUtf8Message(keyPair, message);
    final publicKey = await TkmChatSigning.publicKeyUrl64(keyPair);
    expect(publicKey.length, 44);
    expect(signature.length, 88);
    final valid = await TkmChatSigning.verifyUtf8Message(
      publicKeyUrl64: publicKey,
      signatureUrl64: signature,
      message: message,
    );
    expect(valid, isTrue);
  });
}
