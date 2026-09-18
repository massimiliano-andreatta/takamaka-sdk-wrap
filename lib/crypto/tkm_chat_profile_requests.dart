import 'package:takamaka_sdk_wrap/constants/chat_message_types.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';
import 'package:takamaka_sdk_wrap/models/chat/tkm_chat_profile_models.dart';

/// Signed envelope builders for the user-profile RSocket routes.
///
/// Wire shape: `message_type` = CHAT_MESSAGE_TYPES enum (e.g. `SET_USER_PROFILE`),
/// signed content under `pl`. Route names stay lowercase (`setuserprofile`).
abstract final class TkmChatProfileRequests {
  static Future<Map<String, dynamic>> buildSetUserProfileRequest({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonceResponse,
    required TkmEncryptedProfile profile,
    required List<TkmProfileGrant> grants,
    int? clientTimestamp,
  }) {
    final pl = <String, dynamic>{
      'nonce': _noncePl(nonceResponse),
      'profile': profile.toJson(),
      'grants': grants.map((g) => g.toJson()).toList(),
      'client_timestamp':
          clientTimestamp ?? DateTime.now().millisecondsSinceEpoch,
    };
    return _signedPl(
      keys: keys,
      messageType: ChatMessageTypes.setUserProfile,
      pl: pl,
    );
  }

  static Future<Map<String, dynamic>> buildPutProfileGrantsRequest({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonceResponse,
    required int keyEpoch,
    required List<TkmProfileGrant> grants,
    int? clientTimestamp,
  }) {
    final pl = <String, dynamic>{
      'nonce': _noncePl(nonceResponse),
      'key_epoch': keyEpoch,
      'grants': grants.map((g) => g.toJson()).toList(),
      'client_timestamp':
          clientTimestamp ?? DateTime.now().millisecondsSinceEpoch,
    };
    return _signedPl(
      keys: keys,
      messageType: ChatMessageTypes.putProfileGrants,
      pl: pl,
    );
  }

  static Future<Map<String, dynamic>> buildClearUserProfileRequest({
    required ChatKeyMaterial keys,
    required Map<String, dynamic> nonceResponse,
    int? clientTimestamp,
  }) {
    final pl = <String, dynamic>{
      'nonce': _noncePl(nonceResponse),
      'client_timestamp':
          clientTimestamp ?? DateTime.now().millisecondsSinceEpoch,
    };
    return _signedPl(
      keys: keys,
      messageType: ChatMessageTypes.clearUserProfile,
      pl: pl,
    );
  }

  static Future<Map<String, dynamic>> buildGetUserProfileRequest({
    required ChatKeyMaterial keys,
    int? clientTimestamp,
  }) {
    final pl = <String, dynamic>{
      'client_timestamp':
          clientTimestamp ?? DateTime.now().millisecondsSinceEpoch,
    };
    return _signedPl(
      keys: keys,
      messageType: ChatMessageTypes.getUserProfile,
      pl: pl,
    );
  }

  static Future<Map<String, dynamic>> buildGetUserProfilePeerRequest({
    required ChatKeyMaterial keys,
    required String targetPublicKey,
    String? knownBlobHash,
    int? clientTimestamp,
  }) {
    final pl = <String, dynamic>{
      'target_public_key': targetPublicKey,
      'client_timestamp':
          clientTimestamp ?? DateTime.now().millisecondsSinceEpoch,
    };
    if (knownBlobHash != null && knownBlobHash.isNotEmpty) {
      pl['known_blob_hash'] = knownBlobHash;
    }
    return _signedPl(
      keys: keys,
      messageType: ChatMessageTypes.getUserProfilePeer,
      pl: pl,
    );
  }

  static Future<Map<String, dynamic>> buildGetProfileDigestsRequest({
    required ChatKeyMaterial keys,
    required List<String> targetPublicKeys,
    int? clientTimestamp,
  }) {
    final pl = <String, dynamic>{
      'target_public_keys': targetPublicKeys,
      'client_timestamp':
          clientTimestamp ?? DateTime.now().millisecondsSinceEpoch,
    };
    return _signedPl(
      keys: keys,
      messageType: ChatMessageTypes.getProfileDigests,
      pl: pl,
    );
  }

  static Future<Map<String, dynamic>> _signedPl({
    required ChatKeyMaterial keys,
    required String messageType,
    required Map<String, dynamic> pl,
  }) async {
    final signature =
        await TkmChatSigning.signCanonicalJson(keys.signKeyPair, pl);
    final from = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    return TkmChatSigning.signedEnvelope(
      from: from,
      signature: signature,
      messageType: messageType,
      signedContentKey: 'pl',
      signedContentField: pl,
    );
  }

  /// Only the three NonceResponseBean fields enter `pl` (parity with
  /// `NonceResponseBean.toJson` / Jackson beans) so extras from the transport
  /// cannot diverge signed canonical JSON from the server's re-parse.
  static Map<String, dynamic> _noncePl(Map<String, dynamic> nonceResponse) {
    final nonce = nonceResponse['nonce'];
    final timestamp = nonceResponse['timestamp'];
    final liveness = nonceResponse['liveness'];
    return <String, dynamic>{
      if (nonce != null) 'nonce': nonce,
      if (timestamp != null)
        'timestamp': timestamp is num ? timestamp.toInt() : timestamp,
      if (liveness != null)
        'liveness': liveness is num ? liveness.toInt() : liveness,
    };
  }
}
