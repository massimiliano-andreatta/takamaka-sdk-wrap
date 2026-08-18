import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/constants/chat_server_endpoints.dart';

/// RSocket route names must match server [ChatServerEndpoints] (SERVER_API_GUIDE §5).
void main() {
  test('routes are lowercase without leading slash', () {
    const routes = [
      ChatServerEndpoints.serverInfo,
      ChatServerEndpoints.nonce,
      ChatServerEndpoints.registerUser,
      ChatServerEndpoints.requestKeys,
      ChatServerEndpoints.createConversation,
      ChatServerEndpoints.messages,
      ChatServerEndpoints.retrieveMessages,
      ChatServerEndpoints.retrieveAllMessages,
      ChatServerEndpoints.retrieveAllConversations,
      ChatServerEndpoints.retrieveConversation,
      ChatServerEndpoints.deleteMessage,
      ChatServerEndpoints.retrieveDeletions,
      ChatServerEndpoints.notification,
      ChatServerEndpoints.notificationHistory,
      ChatServerEndpoints.submitAttachment,
      ChatServerEndpoints.retrieveAttachment,
      ChatServerEndpoints.registerFcmToken,
      ChatServerEndpoints.unregisterFcmToken,
      ChatServerEndpoints.deleteFcmToken,
      ChatServerEndpoints.deleteAllFcmTokens,
      ChatServerEndpoints.timeUpdatesStream,
      ChatServerEndpoints.submitReadReceipt,
      ChatServerEndpoints.retrieveReadReceipts,
      ChatServerEndpoints.typingSubscribe,
      ChatServerEndpoints.typingEmit,
    ];

    for (final route in routes) {
      expect(route, isNot(startsWith('/')));
      expect(route.toLowerCase(), route);
    }
  });

  test('smoke-test stream route from guide §2.3', () {
    expect(
      ChatServerEndpoints.timeUpdatesStream,
      'my.time-updates.stream',
    );
  });

  test('core chat flows use documented route names', () {
    expect(ChatServerEndpoints.nonce, 'nonce');
    expect(ChatServerEndpoints.registerUser, 'registeruser');
    expect(ChatServerEndpoints.requestKeys, 'requestkeys');
    expect(ChatServerEndpoints.createConversation, 'createconversation');
    expect(ChatServerEndpoints.messages, 'messages');
    expect(ChatServerEndpoints.retrieveMessages, 'retrievemessages');
    expect(ChatServerEndpoints.serverInfo, 'serverinfo');
    expect(ChatServerEndpoints.deleteMessage, 'deletemessage');
    expect(ChatServerEndpoints.retrieveDeletions, 'retrievedeletions');
    expect(ChatServerEndpoints.submitReadReceipt, 'submitreadreceipt');
    expect(ChatServerEndpoints.retrieveReadReceipts, 'retrievereadreceipts');
    expect(ChatServerEndpoints.typingSubscribe, 'typingsubscribe');
    expect(ChatServerEndpoints.typingEmit, 'typingemit');
  });

  test('FCM delete routes match fcm_token_delete_api guide', () {
    expect(ChatServerEndpoints.deleteFcmToken, 'deletefcmtoken');
    expect(ChatServerEndpoints.deleteAllFcmTokens, 'deleteallfcmtokens');
  });
}
