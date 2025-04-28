import 'package:json_annotation/json_annotation.dart';
import 'package:takamaka_sdk_wrap/models/messages/tkm_message_action.dart';

part 'tkm_base_bean.g.dart';

@JsonSerializable(includeIfNull: false)
class TkmBaseBean {
  @JsonKey(name: "v")
  final String version;

  @JsonKey(name: "a")
  final TkmMessageAction? messageAction;

  @JsonKey(name: "t")
  final String? typeOfAction;

  @JsonKey(name: "ts")
  final String? typeOfSignature;

  @JsonKey(name: "sg")
  final String? signature;

  @JsonKey(name: "ea")
  final String? encryptedMessageAction;

  TkmBaseBean({
    required this.version,
    required this.messageAction,
    required this.typeOfAction,
    required this.typeOfSignature,
    required this.signature,
    required this.encryptedMessageAction,
  });

  /// Metodo per la serializzazione JSON
  factory TkmBaseBean.fromJson(Map<String, dynamic> json) => _$TkmBaseBeanFromJson(json);

  /// Metodo per la deserializzazione JSON
  Map<String, dynamic> toJson() => _$TkmBaseBeanToJson(this);
}