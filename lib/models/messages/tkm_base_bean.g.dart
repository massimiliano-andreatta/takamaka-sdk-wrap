// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tkm_base_bean.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TkmBaseBean _$TkmBaseBeanFromJson(Map<String, dynamic> json) => TkmBaseBean(
      version: json['v'] as String,
      messageAction: json['a'] == null
          ? null
          : TkmMessageAction.fromJson(json['a'] as Map<String, dynamic>),
      typeOfAction: json['t'] as String?,
      typeOfSignature: json['ts'] as String?,
      signature: json['sg'] as String?,
      encryptedMessageAction: json['ea'] as String?,
    );

Map<String, dynamic> _$TkmBaseBeanToJson(TkmBaseBean instance) =>
    <String, dynamic>{
      'v': instance.version,
      if (instance.messageAction case final value?) 'a': value,
      if (instance.typeOfAction case final value?) 't': value,
      if (instance.typeOfSignature case final value?) 'ts': value,
      if (instance.signature case final value?) 'sg': value,
      if (instance.encryptedMessageAction case final value?) 'ea': value,
    };
