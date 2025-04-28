// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tkm_message_action.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TkmMessageAction _$TkmMessageActionFromJson(Map<String, dynamic> json) =>
    TkmMessageAction(
      from: TkmMessageAddress.fromJson(json['fr'] as Map<String, dynamic>),
      to: TkmMessageAddress.fromJson(json['to'] as Map<String, dynamic>),
      date: (json['dt'] as num).toInt(),
      green: BigInt.parse(json['g'] as String),
      red: BigInt.parse(json['r'] as String),
      textMessage: json['tm'] as String?,
      encodedWallet: json['ew'] == null
          ? null
          : TkmEncKeyBean.fromJson(json['ew'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TkmMessageActionToJson(TkmMessageAction instance) =>
    <String, dynamic>{
      'fr': instance.from,
      'to': instance.to,
      'dt': instance.date,
      'g': instance.green.toString(),
      'r': instance.red.toString(),
      if (instance.textMessage case final value?) 'tm': value,
      if (instance.encodedWallet case final value?) 'ew': value,
    };
