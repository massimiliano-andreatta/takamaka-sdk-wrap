/// Stream encryption descriptor for rschat attachments (Java SED wire format).
class StreamEncryptedDescriptor {
  const StreamEncryptedDescriptor({
    required this.passwordHashAlgorithm,
    this.iterations,
    required this.transformation,
    required this.keySpecAlgorithm,
    this.tkVersion,
    this.outputKeyLengthBit,
    this.encoding,
    required this.iv,
    this.ivLengthByte,
    this.tagLengthBit,
    this.encryptedContentHash,
    required this.salt,
    this.digestHashFunction,
  });

  final String passwordHashAlgorithm;
  final int? iterations;
  final String transformation;
  final String keySpecAlgorithm;
  final String? tkVersion;
  final int? outputKeyLengthBit;
  final String? encoding;
  final String iv;
  final int? ivLengthByte;
  final int? tagLengthBit;
  final String? encryptedContentHash;
  final String salt;
  final String? digestHashFunction;

  factory StreamEncryptedDescriptor.standard({
    required String salt,
    required String iv,
    String? encryptedContentHash,
  }) {
    return StreamEncryptedDescriptor(
      passwordHashAlgorithm: 'PBKDF2WithHmacSHA512',
      iterations: 20000,
      transformation: 'AES/GCM/NoPadding',
      keySpecAlgorithm: 'AES',
      tkVersion: 'v0_2_a_stream_gcm',
      outputKeyLengthBit: 256,
      encoding: 'UTF-8',
      salt: salt,
      iv: iv,
      ivLengthByte: 12,
      tagLengthBit: 128,
      encryptedContentHash: encryptedContentHash,
      digestHashFunction: 'SHA3-256',
    );
  }

  factory StreamEncryptedDescriptor.fromJson(Map<String, dynamic> json) {
    return StreamEncryptedDescriptor(
      passwordHashAlgorithm: json['pa'] as String? ?? '',
      iterations: (json['it'] as num?)?.toInt(),
      transformation: json['tr'] as String? ?? '',
      keySpecAlgorithm: json['ka'] as String? ?? '',
      tkVersion: json['tv'] as String?,
      outputKeyLengthBit: (json['kl'] as num?)?.toInt(),
      encoding: json['ec'] as String?,
      iv: json['iv'] as String? ?? '',
      ivLengthByte: (json['iv_length_byte'] as num?)?.toInt(),
      tagLengthBit: (json['tag_length_bit'] as num?)?.toInt(),
      encryptedContentHash: json['encrypted_content_hash'] as String?,
      salt: json['salt'] as String? ?? '',
      digestHashFunction: json['digest_hash_function'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pa': passwordHashAlgorithm,
      'it': iterations,
      'tr': transformation,
      'ka': keySpecAlgorithm,
      'tv': tkVersion,
      'kl': outputKeyLengthBit,
      'ec': encoding,
      'iv': iv,
      'iv_length_byte': ivLengthByte,
      'tag_length_bit': tagLengthBit,
      'encrypted_content_hash': encryptedContentHash,
      'salt': salt,
      'digest_hash_function': digestHashFunction,
    };
  }
}
