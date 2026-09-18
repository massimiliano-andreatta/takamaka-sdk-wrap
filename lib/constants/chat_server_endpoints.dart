/// RSocket route names (no leading slash) — must match server [ChatServerEndpoints].
abstract final class ChatServerEndpoints {
  /// Unsigned capabilities probe (DR-022 / DR-023 transport manifest).
  static const String serverInfo = 'serverinfo';

  static const String nonce = 'nonce';
  static const String registerUser = 'registeruser';
  static const String requestKeys = 'requestkeys';
  static const String createConversation = 'createconversation';
  static const String messages = 'messages';
  static const String retrieveMessages = 'retrievemessages';
  static const String retrieveAllMessages = 'retrieveallmessages';
  static const String retrieveAllConversations = 'retrieveallconversations';
  static const String retrieveConversation = 'retrieveconversation';

  /// Owner-signed "delete for everyone" (DR-025).
  static const String deleteMessage = 'deletemessage';

  /// Deletion-log catch-up stream (DR-025).
  static const String retrieveDeletions = 'retrievedeletions';

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

  /// Signed request-response read receipt (READ_RECEIPT_DESIGN).
  static const String submitReadReceipt = 'submitreadreceipt';

  /// Signed request-stream of read-receipt batches (nonce-gated).
  static const String retrieveReadReceipts = 'retrievereadreceipts';

  /// Signed request-stream typing sink (TYPING_INDICATOR_DESIGN).
  static const String typingSubscribe = 'typingsubscribe';

  /// Plain fire-and-forget typing emit (`{conv, pv}` — no `from`).
  static const String typingEmit = 'typingemit';

  /// User profile channel (profile-integration-protocol.md).
  static const String setUserProfile = 'setuserprofile';
  static const String putProfileGrants = 'putprofilegrants';
  static const String clearUserProfile = 'clearuserprofile';
  static const String getUserProfile = 'getuserprofile';
  static const String getUserProfilePeer = 'getuserprofilepeer';
  static const String getProfileDigests = 'getprofiledigests';
}
