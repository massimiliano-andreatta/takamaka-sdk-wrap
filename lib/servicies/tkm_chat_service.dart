import 'package:takamaka_sdk_wrap/crypto/tkm_chat_crypto.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_rsa.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_chat_enums_api.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';
import 'package:takamaka_sdk_wrap/servicies/api/chat/tkm_chat_client_api.dart';

typedef ChatRsaKeyLoader = Future<TkmChatRsaKeyPair?> Function();
typedef ChatRsaKeySaver = Future<void> Function(TkmChatRsaKeyPair pair);

/// Facade for rschat: session keys + [TkmChatClientApi].
class TkmChatService {
  TkmChatService({
    TkmChatEnumEnvironments environment = TkmChatEnumEnvironments.test,
  }) : _api = TkmChatClientApi(environment: environment);

  final TkmChatClientApi _api;
  ChatKeyMaterial? _keys;
  Map<String, dynamic>? _registeredUser;

  /// Optional persistence for the RSA-4096 invite key (must survive restarts).
  ChatRsaKeyLoader? rsaKeyLoader;
  ChatRsaKeySaver? rsaKeySaver;

  TkmChatClientApi get api => _api;
  ChatKeyMaterial? get keys => _keys;
  Map<String, dynamic>? get registeredUser => _registeredUser;

  Future<void> initializeSession({
    required String walletSeed,
    int signKeyIndex = 0,
    bool forceRegister = false,
    ChatKeyMaterial? restoredKeyMaterial,
  }) async {
    if (!forceRegister &&
        _keys != null &&
        _keys!.signKeyIndex == signKeyIndex &&
        _registeredUser != null) {
      return;
    }

    final canRestore = !forceRegister &&
        restoredKeyMaterial != null &&
        restoredKeyMaterial.signKeyIndex == signKeyIndex;

    if (canRestore) {
      _keys = restoredKeyMaterial;
    } else {
      TkmChatRsaKeyPair? rsaKeyPair;
      if (rsaKeyLoader != null) {
        rsaKeyPair = await rsaKeyLoader!();
      }
      if (rsaKeyPair == null) {
        rsaKeyPair = await TkmChatRsaKeyPair.fromWalletSeed(
          walletSeed,
          signKeyIndex: signKeyIndex,
        );
        if (rsaKeySaver != null) {
          await rsaKeySaver!(rsaKeyPair);
        }
      }

      _keys = await ChatKeyMaterial.fromWalletSeed(
        walletSeed,
        signKeyIndex: signKeyIndex,
        rsaKeyPair: rsaKeyPair,
      );
    }
    final nonce = await _api.getNonce();
    _registeredUser = await TkmChatCrypto.buildRegisterUserRequest(
      keys: _keys!,
      nonceResponse: nonce,
    );
    await _api.registerUserWithRequest(_registeredUser!);
  }

  Future<void> disconnect() => _api.disconnect();

  /// Clears local session state so a different wallet/address can connect.
  Future<void> resetSession() async {
    await disconnect();
    _keys = null;
    _registeredUser = null;
  }
}
