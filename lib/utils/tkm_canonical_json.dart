import 'dart:collection' show SplayTreeMap;
import 'dart:convert';

import 'package:jcs_dart/jcs_dart.dart';

/// RFC 8785 JCS canonical JSON (aligned with Java [JsonCanonicalizer]).
abstract final class TkmCanonicalJson {
  static final JsonCanonicalizer _jcs = JsonCanonicalizer();

  static String encode(Object? value) {
    final compact = jsonEncode(_toJsonSafe(value));
    return _jcs.canonicalize(compact);
  }

  static dynamic _toJsonSafe(dynamic value) {
    if (value is Map) {
      final sorted = SplayTreeMap<String, dynamic>();
      for (final entry in value.entries) {
        sorted[entry.key.toString()] = _toJsonSafe(entry.value);
      }
      return sorted;
    }
    if (value is List) {
      return value.map(_toJsonSafe).toList();
    }
    return value;
  }
}
