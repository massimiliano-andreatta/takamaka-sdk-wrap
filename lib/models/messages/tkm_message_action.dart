import 'package:json_annotation/json_annotation.dart';
import 'package:takamaka_sdk_wrap/models/messages/tkm_enc_key_bean.dart';
import 'package:takamaka_sdk_wrap/models/messages/tkm_message_address.dart';
import 'dart:math';

import 'tkm_message_address.dart';
import 'tkm_enc_key_bean.dart';

part 'tkm_message_action.g.dart';

@JsonSerializable(includeIfNull: false)
class TkmMessageAction {
  @JsonKey(name: "fr")
  final TkmMessageAddress from;

  @JsonKey(name: "to")
  final TkmMessageAddress to;

  @JsonKey(name: "dt")
  final int date;

  @JsonKey(name: "g")
  final BigInt green;

  @JsonKey(name: "r")
  final BigInt red;

  @JsonKey(name: "tm")
  final String? textMessage;

  @JsonKey(name: "ew")
  final TkmEncKeyBean? encodedWallet;

  TkmMessageAction({
    required this.from,
    required this.to,
    required this.date,
    required this.green,
    required this.red,
    this.textMessage,
    this.encodedWallet,
  });

  /// Metodo per deserializzare da JSON
  factory TkmMessageAction.fromJson(Map<String, dynamic> json) => _$TkmMessageActionFromJson(json);

  /// Metodo per serializzare in JSON
  Map<String, dynamic> toJson() => _$TkmMessageActionToJson(this);
}
