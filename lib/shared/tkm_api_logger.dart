library takamaka_sdk_wrap;

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:takamaka_sdk_wrap/models/api/tkm_api_log_entry.dart';

/// Livelli di log disponibili
enum TkmApiLogLevel {
  /// Nessun log
  none,

  /// Solo errori
  error,

  /// Errori e richieste
  request,

  /// Errori, richieste e risposte
  response,

  /// Tutto incluso body completo
  verbose,
}

/// Configurazione del logger API
class TkmApiLoggerConfig {
  /// Livello di log
  final TkmApiLogLevel logLevel;

  /// Se true, logga anche i body delle richieste/risposte
  final bool logBody;

  /// Se true, logga anche gli headers
  final bool logHeaders;

  /// Se true, logga anche i query parameters
  final bool logQueryParams;

  /// Se true, genera e include il comando cURL nei log
  final bool includeCurlCommand;

  /// Massima lunghezza del body da loggare (0 = illimitato)
  final int maxBodyLength;

  /// Lista di URL da escludere dal logging
  final List<String> excludeUrls;

  /// Lista di pattern di URL da escludere dal logging
  final List<RegExp> excludeUrlPatterns;

  /// Tipo di API (wallet, auth, chat)
  final String? apiType;

  /// Callback personalizzato per il logging
  final void Function(TkmApiLogEntry)? onLog;

  const TkmApiLoggerConfig({
    this.logLevel = TkmApiLogLevel.response,
    this.logBody = true,
    this.logHeaders = true,
    this.logQueryParams = true,
    this.includeCurlCommand = true,
    this.maxBodyLength = 10000,
    this.excludeUrls = const [],
    this.excludeUrlPatterns = const [],
    this.apiType,
    this.onLog,
  });

  /// Configurazione di default per produzione (solo errori)
  factory TkmApiLoggerConfig.production() {
    return const TkmApiLoggerConfig(
      logLevel: TkmApiLogLevel.error,
      logBody: false,
      logHeaders: false,
      includeCurlCommand: false,
    );
  }

  /// Configurazione di default per sviluppo (verbose)
  factory TkmApiLoggerConfig.development() {
    return const TkmApiLoggerConfig(
      logLevel: TkmApiLogLevel.verbose,
      logBody: true,
      logHeaders: true,
      includeCurlCommand: true,
    );
  }

  /// Verifica se un URL deve essere escluso dal logging
  bool shouldExcludeUrl(String url) {
    if (excludeUrls.contains(url)) {
      return true;
    }
    for (var pattern in excludeUrlPatterns) {
      if (pattern.hasMatch(url)) {
        return true;
      }
    }
    return false;
  }
}

/// Interceptor per il logging delle chiamate API
class TkmApiLoggerInterceptor extends Interceptor {
  final TkmApiLoggerConfig config;

  TkmApiLoggerInterceptor({TkmApiLoggerConfig? config})
      : config = config ?? TkmApiLoggerConfig.development();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (config.logLevel == TkmApiLogLevel.none) {
      handler.next(options);
      return;
    }

    if (config.shouldExcludeUrl(options.uri.toString())) {
      handler.next(options);
      return;
    }

    final logEntry = TkmApiLogEntry(
      requestTimestamp: DateTime.now(),
      url: options.uri.toString(),
      method: options.method,
      requestHeaders: config.logHeaders ? _sanitizeHeaders(options.headers) : null,
      requestBody: _extractRequestBody(options, config.logLevel),
      apiType: config.apiType,
      curlCommand: config.includeCurlCommand ? _generateCurlCommand(options) : null,
    );

    _logEntry(logEntry, 'REQUEST');

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (config.logLevel == TkmApiLogLevel.none ||
        config.logLevel == TkmApiLogLevel.error ||
        config.logLevel == TkmApiLogLevel.request) {
      handler.next(response);
      return;
    }

    if (config.shouldExcludeUrl(response.requestOptions.uri.toString())) {
      handler.next(response);
      return;
    }

    final requestTime = response.requestOptions.extra['request_timestamp'] as DateTime?;
    final responseTime = DateTime.now();
    final responseTimeMs = requestTime != null
        ? responseTime.difference(requestTime).inMilliseconds
        : null;

    final logEntry = TkmApiLogEntry(
      requestTimestamp: requestTime ?? responseTime,
      responseTimestamp: responseTime,
      url: response.requestOptions.uri.toString(),
      method: response.requestOptions.method,
      requestHeaders: config.logHeaders
          ? _sanitizeHeaders(response.requestOptions.headers)
          : null,
      requestBody: _extractRequestBody(response.requestOptions, config.logLevel),
      statusCode: response.statusCode,
      responseHeaders: config.logHeaders ? _sanitizeHeaders(response.headers.map) : null,
      responseBody: _extractResponseBody(response, config.logLevel),
      responseTimeMs: responseTimeMs,
      apiType: config.apiType,
      curlCommand: config.includeCurlCommand ? _generateCurlCommand(response.requestOptions) : null,
    );

    _logEntry(logEntry, 'RESPONSE');

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (config.logLevel == TkmApiLogLevel.none) {
      handler.next(err);
      return;
    }

    if (config.shouldExcludeUrl(err.requestOptions.uri.toString())) {
      handler.next(err);
      return;
    }

    final requestTime = err.requestOptions.extra['request_timestamp'] as DateTime?;
    final responseTime = DateTime.now();
    final responseTimeMs = requestTime != null
        ? responseTime.difference(requestTime).inMilliseconds
        : null;

    final logEntry = TkmApiLogEntry(
      requestTimestamp: requestTime ?? responseTime,
      responseTimestamp: responseTime,
      url: err.requestOptions.uri.toString(),
      method: err.requestOptions.method,
      requestHeaders: config.logHeaders
          ? _sanitizeHeaders(err.requestOptions.headers)
          : null,
      requestBody: _extractRequestBody(err.requestOptions, config.logLevel),
      statusCode: err.response?.statusCode,
      responseHeaders: config.logHeaders && err.response != null
          ? _sanitizeHeaders(err.response!.headers.map)
          : null,
      responseBody: err.response != null
          ? _extractResponseBody(err.response!, config.logLevel)
          : null,
      responseTimeMs: responseTimeMs,
      error: err.toString(),
      apiType: config.apiType,
      curlCommand: config.includeCurlCommand ? _generateCurlCommand(err.requestOptions) : null,
    );

    _logEntry(logEntry, 'ERROR');

    handler.next(err);
  }

  /// Estrae il body della richiesta in base alla configurazione
  dynamic _extractRequestBody(RequestOptions options, TkmApiLogLevel logLevel) {
    if (!config.logBody || logLevel == TkmApiLogLevel.error || logLevel == TkmApiLogLevel.none) {
      return null;
    }

    if (options.data == null) {
      return null;
    }

    try {
      if (options.data is FormData) {
        final formData = options.data as FormData;
        final fields = <String, dynamic>{};
        for (var field in formData.fields) {
          fields[field.key] = field.value;
        }
        return _truncateBody(fields);
      } else if (options.data is Map || options.data is List) {
        return _truncateBody(options.data);
      } else if (options.data is String) {
        return _truncateBody(options.data);
      } else {
        return options.data.toString();
      }
    } catch (e) {
      return '<Error parsing request body: $e>';
    }
  }

  /// Estrae il body della risposta in base alla configurazione
  dynamic _extractResponseBody(Response response, TkmApiLogLevel logLevel) {
    if (!config.logBody || logLevel == TkmApiLogLevel.error || logLevel == TkmApiLogLevel.none) {
      return null;
    }

    try {
      return _truncateBody(response.data);
    } catch (e) {
      return '<Error parsing response body: $e>';
    }
  }

  /// Tronca il body se supera la lunghezza massima
  dynamic _truncateBody(dynamic body) {
    if (config.maxBodyLength <= 0) {
      return body;
    }

    try {
      final bodyString = body is String ? body : jsonEncode(body);
      if (bodyString.length <= config.maxBodyLength) {
        return body;
      }
      return '${bodyString.substring(0, config.maxBodyLength)}... [truncated ${bodyString.length - config.maxBodyLength} chars]';
    } catch (e) {
      return body;
    }
  }

  /// Sanitizza gli headers rimuovendo informazioni sensibili
  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = Map<String, dynamic>.from(headers);
    final sensitiveKeys = ['authorization', 'authorization-bearer', 'cookie', 'x-api-key'];
    
    for (var key in sensitiveKeys) {
      if (sanitized.containsKey(key)) {
        sanitized[key] = '***REDACTED***';
      }
      // Controlla anche case-insensitive
      final lowerKey = key.toLowerCase();
      sanitized.removeWhere((k, v) => k.toLowerCase() == lowerKey && k != key);
    }
    
    return sanitized;
  }

  /// Genera il comando cURL equivalente alla richiesta
  String _generateCurlCommand(RequestOptions options) {
    final buffer = StringBuffer();
    buffer.write('curl');

    // Metodo HTTP
    if (options.method.toUpperCase() != 'GET') {
      buffer.write(' -X ${options.method.toUpperCase()}');
    }

    // URL completo (include query parameters se presenti)
    final url = options.uri.toString();
    buffer.write(" '$url'");

    // Headers
    if (options.headers.isNotEmpty) {
      for (var entry in options.headers.entries) {
        final key = entry.key;
        final value = entry.value;
        // Escape le virgolette nel valore
        final escapedValue = value.toString().replaceAll("'", "'\\''");
        buffer.write(" -H '$key: $escapedValue'");
      }
    }

    // Body
    if (options.data != null) {
      String bodyData;
      
      if (options.data is FormData) {
        final formData = options.data as FormData;
        // Per FormData, costruiamo i parametri come form-urlencoded
        final fields = <String>[];
        for (var field in formData.fields) {
          final escapedKey = field.key.replaceAll("'", "'\\''");
          final escapedValue = field.value.replaceAll("'", "'\\''");
          fields.add("$escapedKey=$escapedValue");
        }
        // Aggiungi anche i file se presenti
        for (var file in formData.files) {
          final escapedKey = file.key.replaceAll("'", "'\\''");
          final fileName = file.value.filename ?? 'file';
          fields.add("$escapedKey=@$fileName");
        }
        bodyData = fields.join('&');
        buffer.write(" --data-urlencode '$bodyData'");
      } else if (options.data is Map || options.data is List) {
        // JSON
        try {
          bodyData = jsonEncode(options.data);
          // Escape le virgolette
          bodyData = bodyData.replaceAll("'", "'\\''");
          buffer.write(" -d '$bodyData'");
        } catch (e) {
          bodyData = options.data.toString();
          bodyData = bodyData.replaceAll("'", "'\\''");
          buffer.write(" -d '$bodyData'");
        }
      } else if (options.data is String) {
        // Stringa semplice
        bodyData = options.data.toString();
        bodyData = bodyData.replaceAll("'", "'\\''");
        buffer.write(" -d '$bodyData'");
      } else {
        // Altri tipi
        bodyData = options.data.toString();
        bodyData = bodyData.replaceAll("'", "'\\''");
        buffer.write(" -d '$bodyData'");
      }
    }

    return buffer.toString();
  }

  /// Logga una voce di log
  void _logEntry(TkmApiLogEntry entry, String type) {
    if (config.onLog != null) {
      config.onLog!(entry);
    } else {
      // Usa print standard di Dart (funziona sia in Flutter che in Dart puro)
      print('[$type] ${entry.toString()}');
    }
  }
}

/// Helper per creare un client Dio con logging configurato
class TkmApiLogger {
  /// Crea un client Dio con l'interceptor di logging
  /// 
  /// Se [config] non è fornita, usa una configurazione di default che logga
  /// solo gli errori (produzione). Per abilitare logging completo, passa
  /// esplicitamente [TkmApiLoggerConfig.development()].
  /// Default HTTP timeouts for Takamaka API clients (large multipart uploads).
  static BaseOptions defaultBaseOptions() => BaseOptions(
        connectTimeout: const Duration(minutes: 3),
        sendTimeout: const Duration(minutes: 15),
        receiveTimeout: const Duration(minutes: 5),
      );

  static Dio createDioClient({
    TkmApiLoggerConfig? config,
    String? apiType,
    BaseOptions? baseOptions,
  }) {
    final dio = Dio(baseOptions ?? defaultBaseOptions());
    // Configurazione di default: solo errori (produzione)
    // L'applicazione che usa il pacchetto può passare una config esplicita
    final loggerConfig = config ?? TkmApiLoggerConfig.production();
    
    dio.interceptors.add(
      TkmApiLoggerInterceptor(
        config: loggerConfig.copyWith(apiType: apiType ?? loggerConfig.apiType),
      ),
    );

    // Aggiunge timestamp alla richiesta per calcolare il tempo di risposta
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.extra['request_timestamp'] = DateTime.now();
          handler.next(options);
        },
      ),
    );

    return dio;
  }
}

/// Extension per copiare la configurazione con override
extension TkmApiLoggerConfigExtension on TkmApiLoggerConfig {
  TkmApiLoggerConfig copyWith({
    TkmApiLogLevel? logLevel,
    bool? logBody,
    bool? logHeaders,
    bool? logQueryParams,
    bool? includeCurlCommand,
    int? maxBodyLength,
    List<String>? excludeUrls,
    List<RegExp>? excludeUrlPatterns,
    String? apiType,
    void Function(TkmApiLogEntry)? onLog,
  }) {
    return TkmApiLoggerConfig(
      logLevel: logLevel ?? this.logLevel,
      logBody: logBody ?? this.logBody,
      logHeaders: logHeaders ?? this.logHeaders,
      logQueryParams: logQueryParams ?? this.logQueryParams,
      includeCurlCommand: includeCurlCommand ?? this.includeCurlCommand,
      maxBodyLength: maxBodyLength ?? this.maxBodyLength,
      excludeUrls: excludeUrls ?? this.excludeUrls,
      excludeUrlPatterns: excludeUrlPatterns ?? this.excludeUrlPatterns,
      apiType: apiType ?? this.apiType,
      onLog: onLog ?? this.onLog,
    );
  }
}

