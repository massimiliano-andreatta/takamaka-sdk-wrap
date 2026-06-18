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
  }) : _api = TkmChatClientApi(environment: environment) {
    _api.onTransportReconnect = _onTransportReconnect;
  }

  final TkmChatClientApi _api;
  ChatKeyMaterial? _keys;
  Map<String, dynamic>? _registeredUser;
  bool _restoringTransport = false;

  /// Optional persistence for the RSA-4096 invite key (must survive restarts).
  ChatRsaKeyLoader? rsaKeyLoader;
  ChatRsaKeySaver? rsaKeySaver;

  TkmChatClientApi get api => _api;
  ChatKeyMaterial? get keys => _keys;
  Map<String, dynamic>? get registeredUser => _registeredUser;
  bool get isTransportConnected => _api.isTransportConnected;

  Future<void> _onTransportReconnect() async {
    if (_restoringTransport) return;
    final keys = _keys;
    if (keys == null) return;
    _restoringTransport = true;
    try {
      _registeredUser = await _api.reregisterUser(keys: keys);
    } finally {
      _restoringTransport = false;
    }
  }

  /// Opens a fresh WebSocket and re-runs registeruser when the transport died.
  Future<void> ensureLiveTransport() async {
    if (isTransportConnected && _registeredUser != null) return;
    await _api.forceReconnectTransport();
    await _onTransportReconnect();
  }

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
      final derivedRsa = await TkmChatRsaKeyPair.fromWalletSeed(
        walletSeed,
        signKeyIndex: signKeyIndex,
      );
      TkmChatRsaKeyPair? storedRsa;
      if (rsaKeyLoader != null) {
        storedRsa = await rsaKeyLoader!();
      }

      TkmChatRsaKeyPair primaryRsa;
      List<TkmChatRsaKeyPair> fallbacks = const [];
      if (storedRsa == null) {
        primaryRsa = derivedRsa;
        if (rsaKeySaver != null) {
          await rsaKeySaver!(derivedRsa);
        }
      } else if (storedRsa.publicKeyUrl64 == derivedRsa.publicKeyUrl64) {
        primaryRsa = storedRsa;
      } else {
        // Secure storage may hold a legacy ephemeral key while invites on the
        // server were created with the wallet-derived RSA (or vice versa).
        primaryRsa = storedRsa;
        fallbacks = [derivedRsa];
      }

      _keys = await ChatKeyMaterial.fromWalletSeed(
        walletSeed,
        signKeyIndex: signKeyIndex,
        rsaKeyPair: primaryRsa,
        rsaKeyFallbacks: fallbacks,
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

  /// Persists a wallet-derived RSA key that successfully decrypted an invite.
  Future<void> promoteRsaKeyPair(TkmChatRsaKeyPair pair) async {
    final keys = _keys;
    if (keys == null || keys.rsaKeyPair.publicKeyUrl64 == pair.publicKeyUrl64) {
      return;
    }
    _keys = keys.withPromotedRsaKey(pair);
    if (rsaKeySaver != null) {
      await rsaKeySaver!(pair);
    }
  }
}
