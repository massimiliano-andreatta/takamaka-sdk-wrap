import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:io_takamaka_core_wallet/io_takamaka_core_wallet.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:mime/mime.dart';

/// Collects file metadata for BLOB file transactions.
///
/// Replaces [MetadataUtils.collectMetadata] from `io_takamaka_core_wallet`, which
/// crashes with a null check when [lookupMimeType] returns null for the path alone
/// (common on mobile paths or unknown extensions). This implementation uses
/// optional [headerBytes] for magic-number detection and falls back to
/// `application/octet-stream`.
///
/// File bytes are encoded as-is (no resize/recompression).
class TkmBlobMetadataCollect {
  static const int _headerMaxBytes = 64;

  static Future<TkmMetadata> collect(File file, List<String> tags) async {
    MetadataGod.initialize();

    final Map<String, dynamic> extraMetadata = {};
    final tkmMetadata = TkmMetadata();
    tkmMetadata.tags = tags;
    tkmMetadata.platform = Platform.operatingSystem;
    tkmMetadata.type = 'raw';

    if (!file.existsSync()) {
      throw StateError('File not found: ${file.path}');
    }

    final rawBytes = await file.readAsBytes();
    final headerBytes = rawBytes.length <= _headerMaxBytes
        ? rawBytes
        : Uint8List.sublistView(rawBytes, 0, _headerMaxBytes);

    final mimeFromPath = lookupMimeType(file.path);
    final mimeFromSniff = headerBytes.isEmpty
        ? null
        : lookupMimeType(file.path, headerBytes: headerBytes);
    final resolvedMime =
        mimeFromSniff ?? mimeFromPath ?? 'application/octet-stream';

    tkmMetadata.contentType = resolvedMime;
    tkmMetadata.mime = resolvedMime;

    final fileStat = file.statSync();
    extraMetadata['ModifiedTime'] = fileStat.modified.toString();
    extraMetadata['AccessedTime'] = fileStat.accessed.toString();
    extraMetadata['ChangedTime'] = fileStat.changed.toString();
    extraMetadata['FileSize'] = fileStat.size.toString();

    if (resolvedMime.contains('audio')) {
      final metadata = await MetadataGod.readMetadata(file: file.path);
      extraMetadata['title'] = metadata.title;
      extraMetadata['durationMs'] = metadata.durationMs;
      extraMetadata['artist'] = metadata.artist;
      extraMetadata['album'] = metadata.album;
      extraMetadata['albumArtist'] = metadata.albumArtist;
      extraMetadata['trackNumber'] = metadata.trackNumber;
      extraMetadata['trackTotal'] = metadata.trackTotal;
      extraMetadata['discNumber'] = metadata.discNumber;
      extraMetadata['discTotal'] = metadata.discTotal;
      extraMetadata['year'] = metadata.year;
      extraMetadata['genre'] = metadata.genre;
    }

    if (resolvedMime.contains('image')) {
      final data = await readExifFromBytes(rawBytes);
      final readableExtractedData = <String, dynamic>{};
      data.forEach((key, value) {
        readableExtractedData[key] = value.printable;
      });
      extraMetadata.addAll(readableExtractedData);
    }

    tkmMetadata.xParsedBy = 'Default-Parser';
    tkmMetadata.extraMetadata = extraMetadata;
    tkmMetadata.data = base64UrlEncode(rawBytes);

    return tkmMetadata;
  }
}
