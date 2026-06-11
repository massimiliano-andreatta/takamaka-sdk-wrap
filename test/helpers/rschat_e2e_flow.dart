import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_crypto.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_rsa.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_chat_enums_api.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';
import 'package:takamaka_sdk_wrap/servicies/api/chat/tkm_chat_client_api.dart';

/// End-to-end rschat flow (SERVER_API_GUIDE §4): register → keys → topic → message.
class RschatE2eFlow {
  RschatE2eFlow({
    TkmChatEnumEnvironments environment = TkmChatEnumEnvironments.test,
  }) : _api = TkmChatClientApi(environment: environment);

  final TkmChatClientApi _api;

  ChatKeyMaterial? keys;
  Map<String, dynamic>? registeredUserRequest;
  TkmChatRsaKeyPair? _persistedRsa;

  TkmChatClientApi get api => _api;

  Future<void> disconnect() => _api.disconnect();

  Future<void> registerSession({
    required List<String> mnemonic,
    int signKeyIndex = 0,
  }) async {
    final seed = await WalletUtils.generateSeedPWH(mnemonic);
    _persistedRsa ??= await TkmChatRsaKeyPair.generate();
    keys = await ChatKeyMaterial.fromWalletSeed(
      seed,
      signKeyIndex: signKeyIndex,
      rsaKeyPair: _persistedRsa,
    );
    Map<String, dynamic> nonce;
    try {
      nonce = await _api.getNonce();
    } catch (e) {
      throw StateError('rschat getNonce failed: $e');
    }
    registeredUserRequest = await TkmChatCrypto.buildRegisterUserRequest(
      keys: keys!,
      nonceResponse: nonce,
    );
    try {
      await _api.registerUserWithRequest(registeredUserRequest!);
    } catch (e) {
      throw StateError('rschat registeruser failed: $e');
    }
  }

  /// Finds an existing 1:1 conversation with [partnerSignPublicKey] or creates one.
  Future<({String conversationHash, String symmetricKey})> findOrCreateDirectChat({
    required String title,
    required String partnerSignPublicKey,
  }) async {
    final existing = await _findExistingDirectChat(partnerSignPublicKey);
    if (existing != null) return existing;
    return startDirectChat(
      title: title,
      partnerSignPublicKey: partnerSignPublicKey,
    );
  }

  Future<({String conversationHash, String symmetricKey})?> _findExistingDirectChat(
    String partnerSignPublicKey,
  ) async {
    final material = keys;
    if (material == null) return null;
    final from = await TkmChatSigning.publicKeyUrl64(material.signKeyPair);
    final notBefore =
        DateTime.now().subtract(const Duration(days: 90)).millisecondsSinceEpoch;

    try {
      await for (final raw in _api.retrieveAllConversations(
      keys: material,
      notBefore: notBefore,
    )) {
      final hash = raw.replaceAll('"', '').trim();
      if (hash.isEmpty) continue;
      Map<String, dynamic> detail;
      try {
        detail = await _api.retrieveConversation(
          keys: material,
          conversationHash: hash,
        );
      } catch (_) {
        continue;
      }
      final topic = TkmChatCrypto.topicFromRetrieveConversationResponse(detail);
      final members = topic?['topic_members_map']?['topic_invitation_list']
          as Map<String, dynamic>?;
      if (members == null) continue;
      if (!members.containsKey(partnerSignPublicKey) ||
          !members.containsKey(from)) {
        continue;
      }
      final invite = members[from] as Map<String, dynamic>?;
      if (invite == null) continue;
      final symKey = TkmChatCrypto.decryptSymmetricInvite(
        keys: material,
        invite: invite,
      );
      return (conversationHash: hash, symmetricKey: symKey);
    }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Returns conversation hash and symmetric key used for encryption.
  Future<({String conversationHash, String symmetricKey})> startDirectChat({
    required String title,
    required String partnerSignPublicKey,
  }) async {
    final material = keys;
    final me = registeredUserRequest;
    if (material == null || me == null) {
      throw StateError('Call registerSession first');
    }

    final members = <Map<String, dynamic>>[me];
    try {
      await for (final user in _api.requestKeys(
        keys: material,
        otherPublicKeys: [partnerSignPublicKey],
      )) {
        members.add(user);
      }
    } catch (e) {
      throw StateError('requestkeys failed for $partnerSignPublicKey: $e');
    }
    if (members.length < 2) {
      throw StateError(
        'Partner keys not found on server for $partnerSignPublicKey',
      );
    }

    late ({Map<String, dynamic> response, String symmetricKey}) created;
    try {
      created = await _api.createConversation(
        keys: material,
        title: title,
        members: members,
      );
    } catch (e) {
      throw StateError('createconversation failed: $e');
    }

    final hash = created.response['conversation_hash_name'] as String?;
    if (hash == null || hash.isEmpty) {
      throw StateError(
        'createconversation missing conversation_hash_name: ${created.response}',
      );
    }

    return (
      conversationHash: hash,
      symmetricKey: created.symmetricKey,
    );
  }

  Future<Map<String, dynamic>> sendTextMessage({
    required String conversationHash,
    required String symmetricKey,
    required String text,
  }) async {
    final material = keys;
    if (material == null) {
      throw StateError('Call registerSession first');
    }
    return _api.sendMessage(
      keys: material,
      conversationHash: conversationHash,
      symmetricKey: symmetricKey,
      text: text,
    );
  }

  Future<String> mySignPublicKey() async {
    final material = keys;
    if (material == null) throw StateError('Call registerSession first');
    return TkmChatSigning.publicKeyUrl64(material.signKeyPair);
  }
}
