library takamaka_sdk_wrap;

import 'package:equatable/equatable.dart';

/// Modello che rappresenta una voce di log per una chiamata API
class TkmApiLogEntry extends Equatable {
  /// Timestamp della richiesta
  final DateTime requestTimestamp;

  /// Timestamp della risposta
  final DateTime? responseTimestamp;

  /// URL della richiesta
  final String url;

  /// Metodo HTTP (GET, POST, PUT, DELETE, ecc.)
  final String method;

  /// Headers della richiesta
  final Map<String, dynamic>? requestHeaders;

  /// Body della richiesta
  final dynamic requestBody;

  /// Status code della risposta
  final int? statusCode;

  /// Headers della risposta
  final Map<String, dynamic>? responseHeaders;

  /// Body della risposta
  final dynamic responseBody;

  /// Tempo di risposta in millisecondi
  final int? responseTimeMs;

  /// Eventuale errore verificatosi
  final String? error;

  /// Tipo di API (wallet, auth, chat)
  final String? apiType;

  /// Comando cURL equivalente alla chiamata
  final String? curlCommand;

  TkmApiLogEntry({
    required this.requestTimestamp,
    this.responseTimestamp,
    required this.url,
    required this.method,
    this.requestHeaders,
    this.requestBody,
    this.statusCode,
    this.responseHeaders,
    this.responseBody,
    this.responseTimeMs,
    this.error,
    this.apiType,
    this.curlCommand,
  });

  /// Crea una copia del log con alcuni campi modificati
  TkmApiLogEntry copyWith({
    DateTime? requestTimestamp,
    DateTime? responseTimestamp,
    String? url,
    String? method,
    Map<String, dynamic>? requestHeaders,
    dynamic requestBody,
    int? statusCode,
    Map<String, dynamic>? responseHeaders,
    dynamic responseBody,
    int? responseTimeMs,
    String? error,
    String? apiType,
    String? curlCommand,
  }) {
    return TkmApiLogEntry(
      requestTimestamp: requestTimestamp ?? this.requestTimestamp,
      responseTimestamp: responseTimestamp ?? this.responseTimestamp,
      url: url ?? this.url,
      method: method ?? this.method,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      requestBody: requestBody ?? this.requestBody,
      statusCode: statusCode ?? this.statusCode,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      error: error ?? this.error,
      apiType: apiType ?? this.apiType,
      curlCommand: curlCommand ?? this.curlCommand,
    );
  }

  /// Converte il log in una mappa JSON
  Map<String, dynamic> toJson() {
    return {
      'requestTimestamp': requestTimestamp.toIso8601String(),
      'responseTimestamp': responseTimestamp?.toIso8601String(),
      'url': url,
      'method': method,
      'requestHeaders': requestHeaders,
      'requestBody': requestBody,
      'statusCode': statusCode,
      'responseHeaders': responseHeaders,
      'responseBody': responseBody,
      'responseTimeMs': responseTimeMs,
      'error': error,
      'apiType': apiType,
      'curlCommand': curlCommand,
    };
  }

  /// Crea un log da una mappa JSON
  factory TkmApiLogEntry.fromJson(Map<String, dynamic> json) {
    return TkmApiLogEntry(
      requestTimestamp: DateTime.parse(json['requestTimestamp']),
      responseTimestamp: json['responseTimestamp'] != null
          ? DateTime.parse(json['responseTimestamp'])
          : null,
      url: json['url'],
      method: json['method'],
      requestHeaders: json['requestHeaders'],
      requestBody: json['requestBody'],
      statusCode: json['statusCode'],
      responseHeaders: json['responseHeaders'],
      responseBody: json['responseBody'],
      responseTimeMs: json['responseTimeMs'],
      error: json['error'],
      apiType: json['apiType'],
      curlCommand: json['curlCommand'],
    );
  }

  @override
  List<Object?> get props => [
        requestTimestamp,
        responseTimestamp,
        url,
        method,
        requestHeaders,
        requestBody,
        statusCode,
        responseHeaders,
        responseBody,
        responseTimeMs,
        error,
        apiType,
        curlCommand,
      ];

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('=== API Log Entry ===');
    buffer.writeln('API Type: ${apiType ?? "N/A"}');
    buffer.writeln('Method: $method');
    buffer.writeln('URL: $url');
    buffer.writeln('Request Time: ${requestTimestamp.toIso8601String()}');
    if (responseTimestamp != null) {
      buffer.writeln('Response Time: ${responseTimestamp!.toIso8601String()}');
    }
    if (responseTimeMs != null) {
      buffer.writeln('Response Time: ${responseTimeMs}ms');
    }
    if (statusCode != null) {
      buffer.writeln('Status Code: $statusCode');
    }
    if (error != null) {
      buffer.writeln('Error: $error');
    }
    if (requestHeaders != null && requestHeaders!.isNotEmpty) {
      buffer.writeln('Request Headers: $requestHeaders');
    }
    if (requestBody != null) {
      buffer.writeln('Request Body: $requestBody');
    }
    if (responseHeaders != null && responseHeaders!.isNotEmpty) {
      buffer.writeln('Response Headers: $responseHeaders');
    }
    if (responseBody != null) {
      buffer.writeln('Response Body: $responseBody');
    }
    if (curlCommand != null) {
      buffer.writeln('');
      buffer.writeln('cURL Command:');
      buffer.writeln(curlCommand!);
    }
    buffer.writeln('====================');
    return buffer.toString();
  }
}

