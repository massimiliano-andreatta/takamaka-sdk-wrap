class TkmNotificationResponse {
  final int id;

  final String title;
  final String subTitle;
  final String? body;

  final String? linkUrl;

  TkmNotificationResponse({
    required this.id,
    required this.title,
    required this.subTitle,
    this.body,
    this.linkUrl,
  });

  factory TkmNotificationResponse.fromJson(Map<String, dynamic> json) {
    return TkmNotificationResponse(
      id: json['id'],
      title: json['title'],
      subTitle: json['subTitle'],
      body: json['body'],
      linkUrl: json['linkUrl'],
    );
  }
}