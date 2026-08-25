import 'dart:convert';

import 'package:takamaka_sdk_wrap/crypto/tkm_chat_profile_crypto.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_rsa.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';
import 'package:takamaka_sdk_wrap/models/chat/tkm_chat_profile_models.dart';
import 'package:takamaka_sdk_wrap/servicies/api/chat/tkm_chat_client_api.dart';

/// High-level profile channel policy (parity with rsclient `ProfileClient`).
///
/// The app still owns: co-member enumeration, persistence, rendering.
abstract final class TkmChatProfileClient {
  /// Resolves registration envelopes for [identityKeys], chunked at 50.
  static Future<List<Map<String, dynamic>>> resolveRegistrations({
    required TkmChatClientApi api,
    required ChatKeyMaterial keys,
    required List<String> identityKeys,
  }) async {
    final unique = identityKeys
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toSet()
        .toList();
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < unique.length; i += TkmChatProfileConstants.requestKeysBatchLimit) {
      final end = (i + TkmChatProfileConstants.requestKeysBatchLimit < unique.length)
          ? i + TkmChatProfileConstants.requestKeysBatchLimit
          : unique.length;
      final chunk = unique.sublist(i, end);
      await for (final event in api.requestKeys(
        keys: keys,
        otherPublicKeys: chunk,
      )) {
        final envelope = _asRegistrationEnvelope(event);
        if (envelope != null) out.add(envelope);
      }
    }
    return out;
  }

  /// Publish card + grant every co-member registration, paging overflow.
  static Future<TkmProfileWriteResult> setProfileGrantingAll({
    required TkmChatClientApi api,
    required ChatKeyMaterial keys,
    required TkmProfileCard card,
    required List<Map<String, dynamic>> coMemberRegistrations,
    Set<String> excluded = const {},
    int maxGrantsPerWrite = TkmChatProfileConstants.defaultMaxGrantsPerWrite,
  }) async {
    final selfPk = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    final excludedNorm = excluded.map(_normKey).toSet()..add(_normKey(selfPk));

    final grants = <TkmProfileGrant>[];
    // Placeholder epoch — replaced after nonce fetch / seal.
    final nonce = await api.getNonce() ?? {};
    final keyEpoch = (nonce['timestamp'] as num?)?.toInt() ?? 0;
    if (keyEpoch <= 0) {
      return const TkmProfileWriteResult(
        applied: false,
        error: 'invalid_nonce',
        keyEpoch: 0,
        profileKey: '',
        grantsPublished: 0,
      );
    }

    final normalizedCard = TkmProfileCard(
      displayName: TkmChatProfileCrypto.normalizeField(
        card.displayName,
        TkmChatProfileConstants.maxDisplayNameChars,
      ),
      statusMessage: TkmChatProfileCrypto.normalizeField(
        card.statusMessage,
        TkmChatProfileConstants.maxStatusMessageChars,
      ),
      avatar: card.avatar,
      avatarMediaType: card.avatarMediaType,
    );

    final sealed = TkmChatProfileCrypto.sealCard(
      card: normalizedCard,
      keyEpoch: keyEpoch,
    );

    for (final reg in coMemberRegistrations) {
      final grantee = (reg['from'] as String?)?.trim() ?? '';
      if (grantee.isEmpty || excludedNorm.contains(_normKey(grantee))) {
        continue;
      }
      final content = reg['register_user_request_signed_content'];
      if (content is! Map) continue;
      final encPk = content['encryption_public_key'] as String?;
      if (encPk == null || encPk.isEmpty) continue;
      grants.add(
        TkmChatProfileCrypto.buildGrant(
          granteeIdentityKey: grantee,
          keyEpoch: keyEpoch,
          profileKeyText: sealed.profileKeyText,
          peerEncryptionPublicKey: encPk,
        ),
      );
    }

    final firstPage = grants.take(maxGrantsPerWrite).toList();
    final overflow = grants.length > maxGrantsPerWrite
        ? grants.sublist(maxGrantsPerWrite)
        : <TkmProfileGrant>[];

    final writeResp = await api.setUserProfile(
      keys: keys,
      nonce: nonce,
      profile: sealed.encrypted,
      grants: firstPage,
    );
    final applied = writeResp['applied'] == true;
    final writeError = writeResp['error']?.toString();
    if (!applied) {
      return TkmProfileWriteResult(
        applied: false,
        error: writeError ?? 'setuserprofile_rejected',
        keyEpoch: keyEpoch,
        profileKey: sealed.profileKeyText,
        grantsPublished: 0,
      );
    }

    var published = firstPage.length;
    String? partialError;
    for (var i = 0; i < overflow.length; i += maxGrantsPerWrite) {
      final end = (i + maxGrantsPerWrite < overflow.length)
          ? i + maxGrantsPerWrite
          : overflow.length;
      final page = overflow.sublist(i, end);
      final pageNonce = await api.getNonce() ?? {};
      final pageResp = await api.putProfileGrants(
        keys: keys,
        nonce: pageNonce,
        keyEpoch: keyEpoch,
        grants: page,
      );
      if (pageResp['applied'] == true) {
        published += page.length;
      } else {
        partialError =
            'partial_grants:${pageResp['error'] ?? 'putprofilegrants_failed'}';
        break;
      }
    }

    return TkmProfileWriteResult(
      applied: true,
      error: partialError ?? writeError,
      keyEpoch: keyEpoch,
      profileKey: sealed.profileKeyText,
      grantsPublished: published,
    );
  }

  /// Additive grants under an existing epoch (new co-members / re-reg).
  static Future<TkmProfileWriteResult> grantToNewCoMembers({
    required TkmChatClientApi api,
    required ChatKeyMaterial keys,
    required String profileKeyText,
    required int keyEpoch,
    required List<Map<String, dynamic>> coMemberRegistrations,
    Set<String> excluded = const {},
    int maxGrantsPerWrite = TkmChatProfileConstants.defaultMaxGrantsPerWrite,
  }) async {
    final selfPk = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
    final excludedNorm = excluded.map(_normKey).toSet()..add(_normKey(selfPk));
    final grants = <TkmProfileGrant>[];
    for (final reg in coMemberRegistrations) {
      final grantee = (reg['from'] as String?)?.trim() ?? '';
      if (grantee.isEmpty || excludedNorm.contains(_normKey(grantee))) {
        continue;
      }
      final content = reg['register_user_request_signed_content'];
      if (content is! Map) continue;
      final encPk = content['encryption_public_key'] as String?;
      if (encPk == null || encPk.isEmpty) continue;
      grants.add(
        TkmChatProfileCrypto.buildGrant(
          granteeIdentityKey: grantee,
          keyEpoch: keyEpoch,
          profileKeyText: profileKeyText,
          peerEncryptionPublicKey: encPk,
        ),
      );
    }

    var published = 0;
    String? error;
    for (var i = 0; i < grants.length; i += maxGrantsPerWrite) {
      final end = (i + maxGrantsPerWrite < grants.length)
          ? i + maxGrantsPerWrite
          : grants.length;
      final page = grants.sublist(i, end);
      final nonce = await api.getNonce() ?? {};
      final resp = await api.putProfileGrants(
        keys: keys,
        nonce: nonce,
        keyEpoch: keyEpoch,
        grants: page,
      );
      if (resp['applied'] == true) {
        published += page.length;
      } else {
        error = resp['error']?.toString() ?? 'putprofilegrants_failed';
        break;
      }
    }

    return TkmProfileWriteResult(
      applied: error == null,
      error: error,
      keyEpoch: keyEpoch,
      profileKey: profileKeyText,
      grantsPublished: published,
    );
  }

  /// Rotate epoch and re-grant everyone except [excluded] (plus previous list).
  static Future<TkmProfileWriteResult> excludePeer({
    required TkmChatClientApi api,
    required ChatKeyMaterial keys,
    required TkmProfileCard card,
    required List<Map<String, dynamic>> coMemberRegistrations,
    required Set<String> excluded,
  }) {
    return setProfileGrantingAll(
      api: api,
      keys: keys,
      card: card,
      coMemberRegistrations: coMemberRegistrations,
      excluded: excluded,
    );
  }

  static Future<TkmProfileWriteResult> clearProfile({
    required TkmChatClientApi api,
    required ChatKeyMaterial keys,
  }) async {
    final nonce = await api.getNonce() ?? {};
    final resp = await api.clearUserProfile(keys: keys, nonce: nonce);
    return TkmProfileWriteResult(
      applied: resp['applied'] == true,
      error: resp['error']?.toString(),
      keyEpoch: (nonce['timestamp'] as num?)?.toInt() ?? 0,
      profileKey: '',
      grantsPublished: 0,
    );
  }

  /// Returns targets whose digest differs from [knownHashes] (or are new).
  static Future<List<String>> changedSince({
    required TkmChatClientApi api,
    required ChatKeyMaterial keys,
    required List<String> targets,
    required Map<String, String> knownHashes,
    int maxDigestBatch = TkmChatProfileConstants.defaultMaxDigestBatch,
  }) async {
    final unique = targets
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    final stale = <String>[];
    for (var i = 0; i < unique.length; i += maxDigestBatch) {
      final end = (i + maxDigestBatch < unique.length)
          ? i + maxDigestBatch
          : unique.length;
      final chunk = unique.sublist(i, end);
      final digests = await api.getProfileDigests(
        keys: keys,
        targetPublicKeys: chunk,
      );
      final byTarget = <String, TkmProfileDigest>{};
      for (final d in digests) {
        byTarget[d.target] = d;
      }
      for (final target in chunk) {
        final digest = byTarget[target];
        if (digest == null) continue;
        final known = knownHashes[target];
        if (known == null ||
            known.isEmpty ||
            known.toLowerCase() != digest.blobHash.toLowerCase()) {
          stale.add(target);
        }
      }
    }
    return stale;
  }

  static Future<TkmCachedProfile?> readPeer({
    required TkmChatClientApi api,
    required ChatKeyMaterial keys,
    required String targetPublicKey,
    String? knownBlobHash,
    TkmChatRsaKeyPair? encryptionKeystore,
  }) async {
    final detailed = await readPeerDetailed(
      api: api,
      keys: keys,
      targetPublicKey: targetPublicKey,
      knownBlobHash: knownBlobHash,
      encryptionKeystore: encryptionKeystore,
    );
    if (detailed.status == TkmPeerProfile.visible && detailed.card != null) {
      return TkmCachedProfile(
        target: targetPublicKey,
        blobHash: detailed.blobHash ?? '',
        keyEpoch: detailed.keyEpoch ?? 0,
        card: detailed.card!,
      );
    }
    if (detailed.status == TkmPeerProfile.unchanged && detailed.card != null) {
      return TkmCachedProfile(
        target: targetPublicKey,
        blobHash: knownBlobHash ?? detailed.blobHash ?? '',
        keyEpoch: detailed.keyEpoch ?? 0,
        card: detailed.card!,
      );
    }
    return null;
  }

  static Future<TkmPeerProfile> readPeerDetailed({
    required TkmChatClientApi api,
    required ChatKeyMaterial keys,
    required String targetPublicKey,
    String? knownBlobHash,
    TkmChatRsaKeyPair? encryptionKeystore,
    TkmProfileCard? cachedCard,
    int? cachedKeyEpoch,
  }) async {
    final resp = await api.getUserProfilePeer(
      keys: keys,
      targetPublicKey: targetPublicKey,
      knownBlobHash: knownBlobHash,
    );
    final status = resp['status'] as String? ?? TkmPeerProfile.notVisible;
    if (status == TkmPeerProfile.unchanged) {
      return TkmPeerProfile(
        status: TkmPeerProfile.unchanged,
        blobHash: knownBlobHash,
        keyEpoch: cachedKeyEpoch,
        card: cachedCard,
      );
    }
    if (status != TkmPeerProfile.visible) {
      return TkmPeerProfile(status: status);
    }

    final profileRaw = resp['profile'];
    final grantRaw = resp['grant'];
    if (profileRaw is! Map || grantRaw is! Map) {
      return const TkmPeerProfile(status: TkmPeerProfile.noGrant);
    }
    final encrypted =
        TkmEncryptedProfile.fromJson(Map<String, dynamic>.from(profileRaw));
    final grant = TkmProfileGrant.fromJson(Map<String, dynamic>.from(grantRaw));
    final rsa = encryptionKeystore ?? keys.rsaKeyPair;
    try {
      final keyText = TkmChatProfileCrypto.unwrapGrant(
        grant: grant,
        rsaKeyPair: rsa,
        ownEncryptionPublicKey: rsa.publicKeyUrl64,
      );
      final card = TkmChatProfileCrypto.unsealCard(
        encrypted: encrypted,
        profileKeyText: keyText,
      );
      return TkmPeerProfile(
        status: TkmPeerProfile.visible,
        blobHash: encrypted.blobHash,
        keyEpoch: encrypted.keyEpoch,
        card: card,
      );
    } catch (_) {
      return const TkmPeerProfile(status: TkmPeerProfile.noGrant);
    }
  }

  static Map<String, dynamic>? _asRegistrationEnvelope(
    Map<String, dynamic> event,
  ) {
    if (event['from'] is String &&
        event['register_user_request_signed_content'] is Map) {
      return Map<String, dynamic>.from(event);
    }
    final nested = event['register_user_request_bean'];
    if (nested is Map) {
      final map = Map<String, dynamic>.from(nested);
      if (map['from'] is String &&
          map['register_user_request_signed_content'] is Map) {
        return map;
      }
    }
    return null;
  }

  static String _normKey(String key) =>
      key.trim().replaceAll('=', '.').replaceAll(RegExp(r'\.+$'), '');
}

/// Helper to decode own profile response and unseal when key is known.
abstract final class TkmChatProfileOwnReader {
  static TkmProfileCard? tryUnsealOwn({
    required Map<String, dynamic> getUserProfileResponse,
    required String? profileKeyText,
  }) {
    if (getUserProfileResponse['cleared'] == true) return null;
    final profileRaw = getUserProfileResponse['profile'];
    if (profileRaw is! Map || profileKeyText == null || profileKeyText.isEmpty) {
      return null;
    }
    try {
      final encrypted =
          TkmEncryptedProfile.fromJson(Map<String, dynamic>.from(profileRaw));
      return TkmChatProfileCrypto.unsealCard(
        encrypted: encrypted,
        profileKeyText: profileKeyText,
      );
    } catch (_) {
      return null;
    }
  }

  static String? avatarBytesToStandardBase64(List<int> bytes) =>
      base64Encode(bytes);
}
