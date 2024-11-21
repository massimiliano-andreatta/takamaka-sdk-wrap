class TkmAddressResponse {
  final String address;
  final String type;
  final int uid;
  final bool isActive;
  final bool isMain;
  final String? jsonTrx;
  final String? base64Identicon;

  TkmAddressResponse({
    required this.address,
    required this.type,
    required this.uid,
    required this.isActive,
    required this.isMain,
    this.jsonTrx,
    this.base64Identicon,
  });

  factory TkmAddressResponse.fromJson(Map<String, dynamic> json) {
    return TkmAddressResponse(
      address: json['address'],
      type: json['type'],
      uid: json['uid'],
      isActive: json['is_active'] == 1,
      isMain: json['is_main'] == true,
      jsonTrx: json['json_trx'],
      base64Identicon: json['base64_identicon'],
    );
  }
}
