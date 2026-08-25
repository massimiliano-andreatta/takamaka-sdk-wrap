/// Constants and beans for the rschat user-profile channel.
abstract final class TkmChatProfileConstants {
  static const String payloadVersion10 = '1.0';
  static const String blobVersion10 = '1.0';
  static const String cipherAes256Gcm = 'AES_256_GCM';

  /// Decoded avatar hard cap (registry §4.6) — not advertised by serverinfo.
  static const int maxAvatarBytes = 131072;

  static const int maxDisplayNameChars = 64;
  static const int maxStatusMessageChars = 128;
  static const int maxAvatarEdgePx = 512;
  static const int maxPixelGuard = 50000000;

  /// `requestkeys` rejects batches over this outright (not in manifest).
  static const int requestKeysBatchLimit = 50;

  static const int defaultMaxGrantsPerWrite = 256;
  static const int defaultMaxDigestBatch = 50;
  static const int defaultMaxBlobB64Chars = 245760;
}

/// Plaintext profile card (never sent in the clear).
class TkmProfileCard {
  const TkmProfileCard({
    this.payloadVersion = TkmChatProfileConstants.payloadVersion10,
    this.displayName,
    this.statusMessage,
    this.avatar,
    this.avatarMediaType,
  });

  final String payloadVersion;
  final String? displayName;
  final String? statusMessage;

  /// Raw image bytes as standard base64 (not URL-safe).
  final String? avatar;
  final String? avatarMediaType;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'payload_version': payloadVersion,
    };
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      map['display_name'] = name;
    }
    final status = statusMessage?.trim();
    if (status != null && status.isNotEmpty) {
      map['status_message'] = status;
    }
    if (avatar != null && avatar!.isNotEmpty) {
      map['avatar'] = avatar;
      if (avatarMediaType != null && avatarMediaType!.isNotEmpty) {
        map['avatar_media_type'] = avatarMediaType!.toLowerCase();
      }
    }
    return map;
  }

  factory TkmProfileCard.fromJson(Map<String, dynamic> json) {
    return TkmProfileCard(
      payloadVersion: json['payload_version'] as String? ??
          TkmChatProfileConstants.payloadVersion10,
      displayName: json['display_name'] as String?,
      statusMessage: json['status_message'] as String?,
      avatar: json['avatar'] as String?,
      avatarMediaType: json['avatar_media_type'] as String?,
    );
  }
}

/// Sealed profile blob on the wire.
class TkmEncryptedProfile {
  const TkmEncryptedProfile({
    required this.keyEpoch,
    required this.blob,
    required this.blobHash,
    this.blobVersion = TkmChatProfileConstants.blobVersion10,
    this.cipher = TkmChatProfileConstants.cipherAes256Gcm,
  });

  final int keyEpoch;
  final String blobVersion;
  final String cipher;
  final String blob;
  final String blobHash;

  Map<String, dynamic> toJson() => {
        'key_epoch': keyEpoch,
        'blob_version': blobVersion,
        'cipher': cipher,
        'blob': blob,
        'blob_hash': blobHash,
      };

  factory TkmEncryptedProfile.fromJson(Map<String, dynamic> json) {
    return TkmEncryptedProfile(
      keyEpoch: (json['key_epoch'] as num?)?.toInt() ?? 0,
      blobVersion: json['blob_version'] as String? ??
          TkmChatProfileConstants.blobVersion10,
      cipher: json['cipher'] as String? ??
          TkmChatProfileConstants.cipherAes256Gcm,
      blob: json['blob'] as String? ?? '',
      blobHash: json['blob_hash'] as String? ?? '',
    );
  }
}

/// RSA-wrapped profile key for one grantee.
class TkmProfileGrant {
  const TkmProfileGrant({
    required this.grantee,
    required this.keyEpoch,
    required this.encKeyHash,
    required this.encKey,
  });

  final String grantee;
  final int keyEpoch;
  final String encKeyHash;
  final String encKey;

  Map<String, dynamic> toJson() => {
        'grantee': grantee,
        'key_epoch': keyEpoch,
        'enc_key_hash': encKeyHash,
        'enc_key': encKey,
      };

  factory TkmProfileGrant.fromJson(Map<String, dynamic> json) {
    return TkmProfileGrant(
      grantee: json['grantee'] as String? ?? '',
      keyEpoch: (json['key_epoch'] as num?)?.toInt() ?? 0,
      encKeyHash: json['enc_key_hash'] as String? ?? '',
      encKey: json['enc_key'] as String? ?? '',
    );
  }
}

class TkmProfileWriteResult {
  const TkmProfileWriteResult({
    required this.applied,
    required this.keyEpoch,
    required this.profileKey,
    required this.grantsPublished,
    this.error,
  });

  final bool applied;
  final String? error;
  final int keyEpoch;

  /// Base64URL text of the 32-byte profile key.
  final String profileKey;
  final int grantsPublished;
}

/// Locally cached decrypted peer card.
class TkmCachedProfile {
  const TkmCachedProfile({
    required this.target,
    required this.blobHash,
    required this.keyEpoch,
    required this.card,
  });

  final String target;
  final String blobHash;
  final int keyEpoch;
  final TkmProfileCard card;
}

/// Peer profile read with distinct status (registry §4.5 / D11).
class TkmPeerProfile {
  const TkmPeerProfile({
    required this.status,
    this.blobHash,
    this.keyEpoch,
    this.card,
  });

  /// `visible` | `unchanged` | `no_grant` | `cleared` | `not_visible`
  final String status;
  final String? blobHash;
  final int? keyEpoch;
  final TkmProfileCard? card;

  static const String visible = 'visible';
  static const String unchanged = 'unchanged';
  static const String noGrant = 'no_grant';
  static const String cleared = 'cleared';
  static const String notVisible = 'not_visible';
}

class TkmEncodedAvatar {
  const TkmEncodedAvatar({
    required this.bytes,
    required this.mediaType,
    required this.width,
    required this.height,
  });

  final List<int> bytes;
  final String mediaType;
  final int width;
  final int height;
}

class TkmProfileDigest {
  const TkmProfileDigest({
    required this.target,
    required this.keyEpoch,
    required this.blobHash,
    this.updatedAt,
  });

  final String target;
  final int keyEpoch;
  final String blobHash;
  final int? updatedAt;

  factory TkmProfileDigest.fromJson(Map<String, dynamic> json) {
    return TkmProfileDigest(
      target: json['target'] as String? ?? '',
      keyEpoch: (json['key_epoch'] as num?)?.toInt() ?? 0,
      blobHash: json['blob_hash'] as String? ?? '',
      updatedAt: (json['updated_at'] as num?)?.toInt(),
    );
  }
}
