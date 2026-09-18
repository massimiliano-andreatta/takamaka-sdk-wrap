class TkmLoginResponse {
  final String token;
  String? refreshToken;

  TkmLoginResponse({required this.token, required this.refreshToken});

  factory TkmLoginResponse.fromJson(Map<String, dynamic> json) {
    return TkmLoginResponse(
      token: json['token'], refreshToken: json['refresh-token'],
    );
  }
}