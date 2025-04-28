import 'package:json_annotation/json_annotation.dart';

part 'tkm_enc_key_bean.g.dart';

@JsonSerializable()
class TkmEncKeyBean {
  final String encryptedKey;

  TkmEncKeyBean({required this.encryptedKey});

  factory TkmEncKeyBean.fromJson(Map<String, dynamic> json) => _$TkmEncKeyBeanFromJson(json);
  Map<String, dynamic> toJson() => _$TkmEncKeyBeanToJson(this);
}
