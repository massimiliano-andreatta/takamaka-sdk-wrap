import 'dart:convert';

class PayActionData {
  final String recipientAddress;
  final double amountGreen;
  final double amountRed;
  final String? message;
  final int timestamp; // Millisecondi dall'epoca

  PayActionData({
    required this.recipientAddress,
    required this.amountGreen,
    required this.amountRed,
    this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'recipientAddress': recipientAddress,
      'amountGreen': amountGreen,
      'amountRed': amountRed,
      'message': message,
      'timestamp': timestamp,
    };
  }

  factory PayActionData.fromJson(Map<String, dynamic> json) {
    if (json['recipientAddress'] == null ||
        json['amountGreen'] == null ||
        json['amountRed'] == null ||
        json['timestamp'] == null) {
      throw FormatException(
          "Campi obbligatori mancanti nel JSON per PayActionData");
    }
    return PayActionData(
      recipientAddress: json['recipientAddress'] as String,
      amountGreen: (json['amountGreen'] as num).toDouble(),
      amountRed: (json['amountRed'] as num).toDouble(),
      message: json['message'] as String?,
      timestamp: json['timestamp'] as int,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory PayActionData.fromJsonString(String jsonString) {
    try {
      final Map<String, dynamic> jsonMap =
          jsonDecode(jsonString) as Map<String, dynamic>;
      return PayActionData.fromJson(jsonMap);
    } catch (e) {
      // Potrebbe essere utile loggare l'errore e.toString() o rilanciare un'eccezione specifica
      throw FormatException(
          "Errore durante il parsing della stringa JSON per PayActionData: $e");
    }
  }
}
