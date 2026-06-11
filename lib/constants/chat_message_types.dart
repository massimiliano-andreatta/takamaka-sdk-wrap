/// Signed request message_type values — aligned with Java [CHAT_MESSAGE_TYPES].
abstract final class ChatMessageTypes {
  static const String registerUserSignedRequest =
      'REGISTER_USER_SIGNED_REQUEST';
  static const String requestUserKeys = 'REQUEST_USER_KEYS';
  static const String topicCreation = 'TOPIC_CREATION';
  static const String topicMessage = 'TOPIC_MESSAGE';
  static const String notificationRequest = 'NOTIFICATION_REQUEST';
  static const String retrieveMessageLastN =
      'RETRIEVE_MESSAGE_FROM_CONVERSATION_LAST_N';
  static const String retrieveMessageBySignature =
      'RETRIEVE_MESSAGE_FROM_CONVERSATION_BY_SIGNATURE';
  static const String signedTimestamp = 'SIGNED_TIMESTAMP';
  static const String retrieveAllConversations = 'RETRIEVE_ALL_CONVERSATIONS';
  static const String retrieveConversation = 'RETRIEVE_CONVERSATION';
  static const String uploadRequest = 'UPLOAD_REQUEST';
  static const String downloadRequest = 'DOWNLOAD_REQUEST';
}
