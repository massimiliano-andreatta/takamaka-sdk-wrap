import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_encryption.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_profile_avatar_encoder.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_profile_crypto.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_rsa.dart';
import 'package:takamaka_sdk_wrap/models/chat/tkm_chat_profile_models.dart';

void main() {
  group('TkmChatProfileCrypto', () {
    test('seal/unseal round-trip preserves card fields', () {
      final card = TkmProfileCard(
        displayName: 'Alice',
        statusMessage: 'hello',
        avatar: base64Encode(Uint8List.fromList([1, 2, 3, 4])),
        avatarMediaType: 'image/jpeg',
      );
      final sealed = TkmChatProfileCrypto.sealCard(
        card: card,
        keyEpoch: 1756000000000,
      );
      expect(sealed.encrypted.keyEpoch, 1756000000000);
      expect(sealed.encrypted.cipher, TkmChatProfileConstants.cipherAes256Gcm);
      expect(sealed.encrypted.blobHash.length, 64);
      expect(
        sealed.encrypted.blobHash,
        equals(sealed.encrypted.blobHash.toLowerCase()),
      );

      final opened = TkmChatProfileCrypto.unsealCard(
        encrypted: sealed.encrypted,
        profileKeyText: sealed.profileKeyText,
      );
      expect(opened.displayName, 'Alice');
      expect(opened.statusMessage, 'hello');
      expect(opened.avatar, card.avatar);
      expect(opened.avatarMediaType, 'image/jpeg');
    });

    test('blob_hash is over decoded bytes not base64 text', () {
      final sealed = TkmChatProfileCrypto.sealCard(
        card: const TkmProfileCard(displayName: 'Bob'),
        keyEpoch: 1,
      );
      final blobBytes =
          // ignore: invalid_use_of_visible_for_testing_member
          _decodeBlob(sealed.encrypted.blob);
      expect(
        sealed.encrypted.blobHash,
        TkmChatProfileCrypto.sha3Hex(blobBytes),
      );
    });

    test('grant wrap plaintext is Base64URL text of profile key', () async {
      final rsa = await TkmChatRsaKeyPair.generate();
      final keyText = TkmChatProfileCrypto.generateProfileKeyText();
      final grant = TkmChatProfileCrypto.buildGrant(
        granteeIdentityKey: 'peerPk.',
        keyEpoch: 99,
        profileKeyText: keyText,
        peerEncryptionPublicKey: rsa.publicKeyUrl64,
      );
      expect(
        grant.encKeyHash,
        TkmChatEncryption.hashSha3_256B64Url(rsa.publicKeyUrl64),
      );
      final unwrapped = TkmChatProfileCrypto.unwrapGrant(
        grant: grant,
        rsaKeyPair: rsa,
        ownEncryptionPublicKey: rsa.publicKeyUrl64,
      );
      expect(unwrapped, keyText);
    });

    test('sanitizeForDisplay strips bidi overrides', () {
      const dirty = 'Hi\u202Eevil\u202C';
      expect(
        TkmChatProfileCrypto.sanitizeForDisplay(dirty),
        'Hievil',
      );
    });

    test('normalizeField clamps by Unicode code points', () {
      final long = List.filled(70, 'あ').join();
      final out = TkmChatProfileCrypto.normalizeField(
        long,
        TkmChatProfileConstants.maxDisplayNameChars,
      );
      expect(out!.runes.length, TkmChatProfileConstants.maxDisplayNameChars);
    });
  });

  group('TkmChatProfileAvatarEncoder', () {
    test('re-encodes large PNG under 128 KiB JPEG', () {
      final image = img.Image(width: 800, height: 600);
      img.fill(image, color: img.ColorRgb8(40, 120, 200));
      // Add noise so JPEG does not collapse to tiny size.
      for (var y = 0; y < image.height; y += 3) {
        for (var x = 0; x < image.width; x += 3) {
          image.setPixelRgb(x, y, (x * y) % 255, y % 255, x % 255);
        }
      }
      final png = Uint8List.fromList(img.encodePng(image));
      final encoded = TkmChatProfileAvatarEncoder.encode(
        png,
        TkmChatProfileConstants.maxAvatarBytes,
      );
      expect(encoded.bytes.length, lessThanOrEqualTo(131072));
      expect(encoded.mediaType, 'image/jpeg');
      expect(encoded.width, lessThanOrEqualTo(512));
      expect(encoded.height, lessThanOrEqualTo(512));
    });
  });

  group('grant paging arithmetic', () {
    test('pages at 256', () {
      const total = 600;
      const page = TkmChatProfileConstants.defaultMaxGrantsPerWrite;
      final first = total.clamp(0, page);
      final overflow = total > page ? total - page : 0;
      expect(first, 256);
      expect(overflow, 344);
      var pages = 0;
      for (var i = 0; i < overflow; i += page) {
        pages++;
      }
      expect(pages, 2);
    });

    test('requestkeys chunks at 50', () {
      const total = 120;
      const limit = TkmChatProfileConstants.requestKeysBatchLimit;
      final chunks = <int>[];
      for (var i = 0; i < total; i += limit) {
        final end = (i + limit < total) ? i + limit : total;
        chunks.add(end - i);
      }
      expect(chunks, [50, 50, 20]);
    });
  });
}

Uint8List _decodeBlob(String blob) {
  final normalized = blob.replaceAll('.', '=').replaceAll('-', '+').replaceAll('_', '/');
  return Uint8List.fromList(base64Decode(normalized));
}
