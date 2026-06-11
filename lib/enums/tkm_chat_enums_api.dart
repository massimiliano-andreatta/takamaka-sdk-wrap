library takamaka_sdk_wrap;

/// rschat server environments (WebSocket transport).
enum TkmChatEnumEnvironments {
  test('wss://rschat-test.takamaka.org/rschat'),
  production('wss://rschat.takamaka.org/rschat');

  final String wsUrl;

  const TkmChatEnumEnvironments(this.wsUrl);
}
