import 'package:takamaka_sdk_wrap/crypto/tkm_chat_crypto.dart';
import 'package:takamaka_sdk_wrap/crypto/tkm_chat_signing.dart';
import 'package:takamaka_sdk_wrap/models/chat/chat_key_material.dart';
import 'package:takamaka_sdk_wrap/servicies/api/chat/tkm_chat_client_api.dart';

/// Shared decrypt diagnostics for integration smoke tests.
class RschatMessageDecryptHelper {
  const RschatMessageDecryptHelper({
    required this.api,
    required this.keys,
  });

  final TkmChatClientApi api;
  final ChatKeyMaterial keys;

  Future<({String? symmetricKey, String? error, List<String> detailKeys})>
      resolveSymmetricKey(String conversationHash) async {
    try {
      final detail = await api.retrieveConversation(
        keys: keys,
        conversationHash: conversationHash,
      );
      final topic =
          TkmChatCrypto.topicFromRetrieveConversationResponse(detail);
      if (topic == null) {
        return (
          symmetricKey: null,
          error: 'topic not found in response keys=${detail.keys.toList()}',
          detailKeys: detail.keys.map((k) => k.toString()).toList(),
        );
      }

      final myPk = await TkmChatSigning.publicKeyUrl64(keys.signKeyPair);
      final members = topic['topic_members_map']?['topic_invitation_list']
          as Map<String, dynamic>?;
      if (members == null) {
        return (
          symmetricKey: null,
          error: 'topic_invitation_list missing',
          detailKeys: detail.keys.map((k) => k.toString()).toList(),
        );
      }
      if (!members.containsKey(myPk)) {
        return (
          symmetricKey: null,
          error: 'no invite for $myPk (members=${members.keys.length})',
          detailKeys: detail.keys.map((k) => k.toString()).toList(),
        );
      }

      final invite = members[myPk] as Map<String, dynamic>?;
      if (invite == null) {
        return (
          symmetricKey: null,
          error: 'invite map entry null',
          detailKeys: detail.keys.map((k) => k.toString()).toList(),
        );
      }

      try {
        final symKey = TkmChatCrypto.decryptSymmetricInvite(
          keys: keys,
          invite: invite,
        );
        if (symKey.isEmpty) {
          return (
            symmetricKey: null,
            error: 'decryptSymmetricInvite returned empty',
            detailKeys: detail.keys.map((k) => k.toString()).toList(),
          );
        }
        return (
          symmetricKey: symKey,
          error: null,
          detailKeys: detail.keys.map((k) => k.toString()).toList(),
        );
      } catch (e) {
        final encKey = invite['enc_key'] as String? ?? '';
        return (
          symmetricKey: null,
          error: 'RSA invite decrypt failed: $e (enc_key len=${encKey.length}, '
              'hasPlus=${encKey.contains("+")}, hasSlash=${encKey.contains("/")})',
          detailKeys: detail.keys.map((k) => k.toString()).toList(),
        );
      }
    } catch (e) {
      return (
        symmetricKey: null,
        error: 'retrieveConversation failed: $e',
        detailKeys: const <String>[],
      );
    }
  }

  Future<
      ({
        int totalEvents,
        int decryptedCount,
        List<String> sampleTexts,
        List<String> failures,
      })> decryptHistory({
    required String conversationHash,
    required String symmetricKey,
    int limit = 20,
  }) async {
    var totalEvents = 0;
    var decryptedCount = 0;
    final sampleTexts = <String>[];
    final failures = <String>[];

    await for (final event in api.retrieveMessageHistory(
      keys: keys,
      conversationHash: conversationHash,
      limit: limit,
    )) {
      totalEvents++;
      final envelope = TkmChatCrypto.envelopeFromStreamEvent(event);
      if (envelope == null) {
        failures.add('event#$totalEvents: no envelope keys=${event.keys}');
        continue;
      }

      final decrypted = TkmChatCrypto.decryptContentFromMessageEnvelope(
        envelope: envelope,
        symmetricKey: symmetricKey,
        filterConversationHash: conversationHash,
      );
      if (decrypted == null) {
        failures.add('event#$totalEvents: decrypt returned null');
        continue;
      }

      final text = TkmChatCrypto.formatMessageDisplayText(decrypted);
      if (text.isEmpty &&
          (decrypted['attached_media'] is! List ||
              (decrypted['attached_media'] as List).isEmpty)) {
        failures.add(
          'event#$totalEvents: empty plaintext keys=${decrypted.keys.toList()}',
        );
        continue;
      }

      decryptedCount++;
      if (sampleTexts.length < 3 && text.isNotEmpty) {
        sampleTexts.add(text.length > 80 ? '${text.substring(0, 80)}…' : text);
      }
    }

    return (
      totalEvents: totalEvents,
      decryptedCount: decryptedCount,
      sampleTexts: sampleTexts,
      failures: failures,
    );
  }
}
