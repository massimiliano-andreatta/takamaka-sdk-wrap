class TkmSyncAddressResponse {
  bool? error;
  int? userId;
  String? message;

  TkmSyncAddressResponse({this.error, this.userId, this.message});

  TkmSyncAddressResponse.fromJson(Map<String, dynamic> json) {
    error = json['error'];
    userId = json['userId'];
    message = json['message'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['error'] = this.error;
    data['userId'] = this.userId;
    data['message'] = this.message;
    return data;
  }
}
