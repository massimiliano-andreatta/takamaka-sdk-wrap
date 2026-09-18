import 'dart:convert';

class PayQrData {
  final String version;
  final PayActionDetails actionDetails;
  final String actionType;

  PayQrData({
    required this.version,
    required this.actionDetails,
    required this.actionType,
  });

  factory PayQrData.create({
    required String recipientAddressString,
    required String recipientType,
    BigInt? green,
    BigInt? red,
    String? message,
    String version = "1.0",
    String actionType = "rp",
  }) {
    return PayQrData(
      version: version,
      actionType: actionType,
      actionDetails: PayActionDetails(
        recipient: RecipientAddress(
          type: recipientType,
          address: recipientAddressString,
        ),
        greenAmountNanoTkg: green,
        redAmountNanoTkr: red,
        textMessage: message,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'v': version,
      'a': actionDetails.toJson(),
      't': actionType,
    };
    return json;
  }

  factory PayQrData.fromJson(Map<String, dynamic> json) {
    return PayQrData(
      version: json['v'] as String,
      actionDetails:
          PayActionDetails.fromJson(json['a'] as Map<String, dynamic>),
      actionType: json['t'] as String,
    );
  }

  String toJsonString() => json.encode(toJson());

  factory PayQrData.fromJsonString(String jsonString) =>
      PayQrData.fromJson(json.decode(jsonString) as Map<String, dynamic>);
}

class PayActionDetails {
  final RecipientAddress recipient;
  final BigInt? greenAmountNanoTkg;
  final BigInt? redAmountNanoTkr;
  final String? textMessage;

  PayActionDetails({
    required this.recipient,
    this.greenAmountNanoTkg,
    this.redAmountNanoTkr,
    this.textMessage,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'to': recipient.toJson(),
    };
    if (greenAmountNanoTkg != null) {
      json['g'] = greenAmountNanoTkg.toString();
    }
    if (redAmountNanoTkr != null) {
      json['r'] = redAmountNanoTkr.toString();
    }
    if (textMessage != null && textMessage!.isNotEmpty) {
      json['tm'] = textMessage;
    }
    return json;
  }

  factory PayActionDetails.fromJson(Map<String, dynamic> json) {
    return PayActionDetails(
      recipient: RecipientAddress.fromJson(json['to'] as Map<String, dynamic>),
      greenAmountNanoTkg:
          json['g'] == null ? null : BigInt.parse(json['g'] as String),
      redAmountNanoTkr:
          json['r'] == null ? null : BigInt.parse(json['r'] as String),
      textMessage: json['tm'] as String?,
    );
  }
}

class RecipientAddress {
  final String type;
  final String address;

  RecipientAddress({
    required this.type,
    required this.address,
  });

  Map<String, dynamic> toJson() {
    return {
      't': type,
      'ma': address,
    };
  }

  factory RecipientAddress.fromJson(Map<String, dynamic> json) {
    return RecipientAddress(
      type: json['t'] as String,
      address: json['ma'] as String,
    );
  }
}
