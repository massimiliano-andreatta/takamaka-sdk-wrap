/// Signed request message_type values — aligned with Java [CHAT_MESSAGE_TYPES].
abstract final class ChatMessageTypes {
  static const String registerUserSignedRequest =
      'REGISTER_USER_SIGNED_REQUEST';
  static const String fcmTokenRegistration = 'FCM_TOKEN_REGISTRATION';
  static const String requestUserKeys = 'REQUEST_USER_KEYS';
  static const String topicCreation = 'TOPIC_CREATION';
  static const String topicMessage = 'TOPIC_MESSAGE';
  static const String topicMessageMedia = 'TOPIC_MESSAGE_MEDIA';
  static const String notificationRequest = 'NOTIFICATION_REQUEST';
  static const String deleteMessage = 'DELETE_MESSAGE';
  static const String retrieveDeletions = 'RETRIEVE_DELETIONS';
  static const String retrieveMessageLastN =
      'RETRIEVE_MESSAGE_FROM_CONVERSATION_LAST_N';
  static const String retrieveMessageBySignature =
      'RETRIEVE_MESSAGE_FROM_CONVERSATION_BY_SIGNATURE';
  static const String signedTimestamp = 'SIGNED_TIMESTAMP';
  static const String retrieveAllConversations = 'RETRIEVE_ALL_CONVERSATIONS';
  static const String retrieveConversation = 'RETRIEVE_CONVERSATION';
  static const String uploadRequest = 'UPLOAD_REQUEST';
  static const String downloadRequest = 'DOWNLOAD_REQUEST';

  /// Dedicated read-receipt envelope and PBKDF2 scope (READ_RECEIPT_DESIGN D4).
  static const String readReceipt = 'READ_RECEIPT';

  /// Signed subscribe for `retrievereadreceipts`.
  static const String retrieveReadReceipts = 'RETRIEVE_READ_RECEIPTS';

  /// Signed subscribe for `typingsubscribe` (TYPING_INDICATOR_DESIGN).
  static const String typingSubscribe = 'TYPING_SUBSCRIBE';

  // Profile channel (DR-032) — envelope `message_type` is the CHAT_MESSAGE_TYPES
  // enum value (UPPER_SNAKE), distinct from the RSocket route (lowercase).
  // See USER_PROFILE_DESIGN D4 and rsclient ChatMessageTypes.
  static const String setUserProfile = 'SET_USER_PROFILE';
  static const String putProfileGrants = 'PUT_PROFILE_GRANTS';
  static const String clearUserProfile = 'CLEAR_USER_PROFILE';
  static const String getUserProfile = 'GET_USER_PROFILE';
  static const String getProfileDigests = 'GET_PROFILE_DIGESTS';
  static const String getUserProfilePeer = 'GET_USER_PROFILE_PEER';
}
