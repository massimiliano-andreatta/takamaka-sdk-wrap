library takamaka_sdk_wrap;

class TkmWalletTransaction {
  String? sITH;
  int? epoch;
  String? from;
  String? greenValue;
  String? message;
  int? notBefore;
  String? redValue;
  String? sith;
  int? slot;
  String? to;
  String? transactionHash;
  String? transactionType;
  bool? validity;

  TkmWalletTransaction({
    this.sITH,
    this.epoch,
    this.from,
    this.greenValue,
    this.message,
    this.notBefore,
    this.redValue,
    this.sith,
    this.slot,
    this.to,
    this.transactionHash,
    this.transactionType,
    this.validity,
  });

  TkmWalletTransaction.fromJson(Map<String, dynamic> json)
      : sITH = json['SITH'],
        epoch = json['epoch'],
        from = json['from'],
        greenValue = json['greenValue'],
        message = json['message'],
        notBefore = json['notBefore'],
        redValue = json['redValue'],
        sith = json['sith'],
        slot = json['slot'],
        to = json['to'],
        transactionHash = json['transactionHash'],
        transactionType = json['transactionType'],
        validity = json['validity'];

  Map<String, dynamic> toJson() {
    return {
      'SITH': sITH,
      'epoch': epoch,
      'from': from,
      'greenValue': greenValue,
      'message': message,
      'notBefore': notBefore,
      'redValue': redValue,
      'sith': sith,
      'slot': slot,
      'to': to,
      'transactionHash': transactionHash,
      'transactionType': transactionType,
      'validity': validity,
    };
  }

  static List<TkmWalletTransaction> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => TkmWalletTransaction.fromJson(json)).toList();
  }
}
