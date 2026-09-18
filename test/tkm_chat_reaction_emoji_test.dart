import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/takamaka_sdk_wrap.dart';

void main() {
  group('TkmChatCrypto.reactionEmojiFromDecrypted', () {
    test('reads Phase-2 emoji field', () {
      final emoji = TkmChatCrypto.reactionEmojiFromDecrypted({
        'action': 'reaction',
        'targets': ['parent..'],
        'attached_media': [
          {'emoji': '👍'},
        ],
      });
      expect(emoji, '👍');
    });

    test('reads canonical preview base64 glyph', () {
      final preview = base64Encode(utf8.encode('🎉'));
      final emoji = TkmChatCrypto.reactionEmojiFromDecrypted({
        'action': 'reaction',
        'attached_media': [
          {
            'media_type': 'image/png',
            'preview': preview,
            'is_the_object': true,
          },
        ],
      });
      expect(emoji, '🎉');
    });

    test('parseMessageActionFields uses emoji field', () {
      final parsed = TkmChatCrypto.parseMessageActionFields({
        'action': 'reaction',
        'targets': ['parentSig..'],
        'attached_media': [
          {'emoji': '🔥'},
        ],
      });
      expect(parsed.action, 'reaction');
      expect(parsed.reactionEmoji, '🔥');
      expect(parsed.targets, ['parentSig..']);
    });
  });
}
