import 'package:json_annotation/json_annotation.dart';

part 'tkm_message_address.g.dart';

@JsonSerializable()
class TkmMessageAddress {
  final String address;

  TkmMessageAddress({required this.address});

  factory TkmMessageAddress.fromJson(Map<String, dynamic> json) => _$TkmMessageAddressFromJson(json);
  Map<String, dynamic> toJson() => _$TkmMessageAddressToJson(this);
}
