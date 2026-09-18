@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/constants/chat_server_endpoints.dart';
import 'package:takamaka_sdk_wrap/enums/tkm_chat_enums_api.dart';
import 'package:takamaka_sdk_wrap/servicies/api/chat/tkm_chat_client_api.dart';
import 'package:takamaka_sdk_wrap/servicies/api/chat/tkm_rsocket_client.dart';

/// Live smoke tests against rschat (SERVER_API_GUIDE §2.3 / §5.1).
///
/// Run only when network is available:
/// `cd takamaka-sdk-wrap && flutter test --tags integration`
void main() {
  const environment = TkmChatEnumEnvironments.test;
  final wsUrl = environment.wsUrl;

  group('rschat live smoke — $wsUrl', () {
    late TkmChatClientApi api;
    late TkmRsChatClient rawClient;

    setUp(() {
      api = TkmChatClientApi(environment: environment);
      rawClient = TkmRsChatClient(
        wsUrl: wsUrl,
        connectTimeout: const Duration(seconds: 20),
        requestTimeout: const Duration(seconds: 20),
      );
    });

    tearDown(() async {
      await api.disconnect();
      await rawClient.disconnect();
    });

    test('nonce returns UUID v4, timestamp and liveness', () async {
      final response = await api.getNonce();

      expect(response, isNotEmpty);
      final nonce = response['nonce'];
      expect(nonce, isA<String>());
      expect(nonce.toString(), matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      )));

      final timestamp = response['timestamp'];
      expect(timestamp, isA<num>());
      final tsMs = timestamp is int ? timestamp : (timestamp as num).toInt();
      final now = DateTime.now().millisecondsSinceEpoch;
      expect((tsMs - now).abs(), lessThan(const Duration(minutes: 5).inMilliseconds));

      final liveness = response['liveness'];
      expect(liveness, isA<num>());
      expect((liveness as num).toInt(), greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('my.time-updates.stream emits at least one server line', () async {
      String? firstLine;
      await for (final item in rawClient
          .requestStreamText(ChatServerEndpoints.timeUpdatesStream)
          .timeout(const Duration(seconds: 25))) {
        firstLine = item;
        break;
      }

      expect(firstLine, isNotNull);
      expect(firstLine!, isNotEmpty);
      expect(
        firstLine.toLowerCase(),
        anyOf(
          contains('time'),
          contains(RegExp(r'\d{10,}')),
        ),
      );
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}
