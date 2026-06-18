import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/servicies/api/chat/tkm_rsocket_client.dart';

void main() {
  group('TkmRsChatClient.isTransportError', () {
    test('detects closed WebSocket sink errors', () {
      expect(
        TkmRsChatClient.isTransportError(
          StateError('Bad state: StreamSink is closed'),
        ),
        isTrue,
      );
    });

    test('ignores application-level errors', () {
      expect(
        TkmRsChatClient.isTransportError(
          StateError('RS-513: invalid signature'),
        ),
        isFalse,
      );
    });
  });
}
