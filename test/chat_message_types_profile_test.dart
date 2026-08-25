import 'package:flutter_test/flutter_test.dart';
import 'package:takamaka_sdk_wrap/constants/chat_message_types.dart';
import 'package:takamaka_sdk_wrap/constants/chat_server_endpoints.dart';

/// Profile channel: route ≠ envelope message_type (USER_PROFILE_DESIGN D4 /
/// rsclient ChatMessageTypes).
void main() {
  test('profile message_type values are CHAT_MESSAGE_TYPES enums', () {
    expect(ChatMessageTypes.setUserProfile, 'SET_USER_PROFILE');
    expect(ChatMessageTypes.putProfileGrants, 'PUT_PROFILE_GRANTS');
    expect(ChatMessageTypes.clearUserProfile, 'CLEAR_USER_PROFILE');
    expect(ChatMessageTypes.getUserProfile, 'GET_USER_PROFILE');
    expect(ChatMessageTypes.getUserProfilePeer, 'GET_USER_PROFILE_PEER');
    expect(ChatMessageTypes.getProfileDigests, 'GET_PROFILE_DIGESTS');
  });

  test('profile routes stay lowercase and distinct from message_type', () {
    expect(ChatServerEndpoints.setUserProfile, 'setuserprofile');
    expect(
      ChatMessageTypes.setUserProfile,
      isNot(ChatServerEndpoints.setUserProfile),
    );
  });
}
