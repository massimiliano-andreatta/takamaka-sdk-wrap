class TkmLoginRequest {
  final String username;
  final String password;
  final String deviceId;

  TkmLoginRequest({required this.username, required this.password, required this.deviceId});

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'device-id': deviceId,
    };
  }
}