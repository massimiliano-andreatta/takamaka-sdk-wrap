/// RSocket route names (no leading slash) — must match server [ChatServerEndpoints].
abstract final class ChatServerEndpoints {
  static const String nonce = 'nonce';
  static const String registerUser = 'registeruser';
  static const String requestKeys = 'requestkeys';
  static const String createConversation = 'createconversation';
  static const String messages = 'messages';
  static const String retrieveMessages = 'retrievemessages';
  static const String retrieveAllMessages = 'retrieveallmessages';
  static const String retrieveAllConversations = 'retrieveallconversations';
  static const String retrieveConversation = 'retrieveconversation';
  static const String notification = 'notification';
  static const String notificationHistory = 'notificationhistory';
  static const String submitAttachment = 'submitattachment';
  static const String retrieveAttachment = 'retrieveattachment';
  static const String registerFcmToken = 'registerfcmtoken';
  static const String unregisterFcmToken = 'unregisterfcmtoken';

  /// Physical delete of this device's FCM row (identity switch / logout).
  static const String deleteFcmToken = 'deletefcmtoken';

  /// Physical delete of every FCM row for the signing identity.
  static const String deleteAllFcmTokens = 'deleteallfcmtokens';

  static const String timeUpdatesStream = 'my.time-updates.stream';
}
