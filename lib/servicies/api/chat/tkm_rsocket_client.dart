import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:rsocket/core/rsocket_requester.dart';
import 'package:rsocket/metadata/composite_metadata.dart';
import 'package:rsocket/payload.dart';
import 'package:rsocket/rsocket_connector.dart';

/// Low-level RSocket client for rschat (WebSocket + composite routing metadata).
class TkmRsChatClient {
  TkmRsChatClient({
    required this.wsUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.requestTimeout = const Duration(seconds: 30),
    this.streamIdleTimeout,
  });

  final String wsUrl;
  final Duration connectTimeout;
  final Duration requestTimeout;

  /// Optional idle timeout between stream items (e.g. live message feed).
  /// When null, streams stay open until the server closes them.
  final Duration? streamIdleTimeout;

  static const int _routingMimeTypeId = 0x7E;
  static const String _signedUploadMimeType =
      'message/x.io.takamaka.rschat.upload.signed-upload';

  RSocketRequester? _socket;

  /// Whether the underlying WebSocket/RSocket transport is open.
  bool get isConnected => _socket != null && !_socket!.closed;

  /// True when [error] indicates a dead WebSocket (e.g. after server close).
  static bool isTransportError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('streamsink is closed') ||
        text.contains('not connected') ||
        text.contains('connection closed') ||
        text.contains('connection reset') ||
        text.contains('socketexception') ||
        text.contains('websocket');
  }

  Future<void> connect() async {
    if (isConnected) return;
    await disconnect();
    final socket = await RSocketConnector.create()
        .dataMimeType('application/json')
        .metadataMimeType('message/x.rsocket.composite-metadata.v0')
        .keepAlive(20, 180)
        .connect(wsUrl)
        .timeout(connectTimeout);
    if (socket is! RSocketRequester) {
      throw StateError(
          'Unexpected RSocket implementation: ${socket.runtimeType}');
    }
    _socket = socket;
    _wireTransportCloseHandler(socket);
  }

  void _wireTransportCloseHandler(RSocketRequester socket) {
    final connection = socket.connection;
    final previous = connection.closeHandler;
    connection.closeHandler = () {
      previous?.call();
      if (identical(_socket, socket)) {
        _socket = null;
      }
    };
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    socket?.close();
  }

  /// Drops the transport and opens a fresh WebSocket + RSocket setup.
  Future<void> forceReconnect() async {
    await disconnect();
    await connect();
  }

  Future<Map<String, dynamic>?> requestResponse(
    String route, [
    Object? data,
  ]) async {
    await connect();
    final payload = _buildPayload(route, data);
    final response = await _socket!
        .requestResponse!(payload)
        .timeout(requestTimeout);
    return _decodeJsonMap(response);
  }

  Stream<Map<String, dynamic>> requestStream(
    String route, [
    Object? data,
  ]) async* {
    await for (final text in requestStreamText(route, data)) {
      final map = _decodeJsonMapFromUtf8(text);
      if (map != null) yield map;
    }
  }

  /// Raw UTF-8 stream payloads (e.g. [ChatServerEndpoints.timeUpdatesStream]).
  Stream<String> requestStreamText(
    String route, [
    Object? data,
  ]) async* {
    await connect();
    final payload = _buildPayload(route, data);
    final streamFn = _socket!.requestStream;
    if (streamFn == null) {
      throw StateError('RSocket requestStream not supported');
    }
    final stream = streamFn(payload);
    final timed = streamIdleTimeout != null
        ? stream.timeout(
            streamIdleTimeout!,
            onTimeout: (EventSink<Payload?> sink) => sink.close(),
          )
        : stream;
    await for (final item in timed) {
      final text = item?.getDataUtf8();
      if (text != null && text.isNotEmpty) yield text;
    }
  }

  /// Binary stream payloads (e.g. encrypted attachment chunks from retrieveattachment).
  Stream<Uint8List> requestStreamBytes(
    String route, [
    Object? data,
  ]) async* {
    await connect();
    final payload = _buildPayload(route, data);
    final streamFn = _socket!.requestStream;
    if (streamFn == null) {
      throw StateError('RSocket requestStream not supported');
    }
    await for (final item in streamFn(payload)) {
      final bytes = item?.data;
      if (bytes != null && bytes.isNotEmpty) {
        yield Uint8List.fromList(bytes);
      }
    }
  }

  /// Bidirectional upload channel for `submitattachment` with signed metadata.
  Stream<Map<String, dynamic>> requestChannelForUploadJson(
    String route,
    Stream<Uint8List> inputStream,
    String signedUploadJson,
  ) async* {
    await connect();
    final channelFn = _socket!.requestChannel;
    if (channelFn == null) {
      throw StateError('RSocket requestChannel not supported');
    }

    final compositeMetadata =
        _buildCompositeMetadataForUpload(route, signedUploadJson);
    var isFirst = true;
    final payloadStream = inputStream.map((chunk) {
      if (isFirst) {
        isFirst = false;
        return Payload.from(compositeMetadata, chunk);
      }
      return Payload.from(null, chunk);
    });

    await for (final item in channelFn(payloadStream)) {
      final text = item.getDataUtf8();
      if (text == null || text.isEmpty) continue;
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        yield decoded;
      } else if (decoded is Map) {
        yield Map<String, dynamic>.from(decoded);
      }
    }
  }

  Payload _buildPayload(String route, Object? data) {
    final metadata = CompositeMetadata.fromEntries([
      RoutingMetadata(route, []),
    ]).toUint8Array();
    final Uint8List? body =
        data == null ? null : Uint8List.fromList(utf8.encode(jsonEncode(data)));
    return Payload.from(metadata, body);
  }

  Uint8List _buildCompositeMetadataForUpload(
    String route,
    String signedUploadJson,
  ) {
    final buffer = BytesBuilder();
    buffer.add(
      _buildWellKnownMetadataEntry(
        _routingMimeTypeId,
        _buildRawRoutingData(route),
      ),
    );
    buffer.add(
      _buildCustomMetadataEntry(
        _signedUploadMimeType,
        Uint8List.fromList(utf8.encode(signedUploadJson)),
      ),
    );
    return buffer.toBytes();
  }

  Uint8List _buildRawRoutingData(String route) {
    final routeBytes = utf8.encode(route);
    return Uint8List.fromList([routeBytes.length, ...routeBytes]);
  }

  Uint8List _buildWellKnownMetadataEntry(int mimeTypeId, Uint8List data) {
    final buffer = BytesBuilder();
    buffer.addByte(0x80 | (mimeTypeId & 0x7F));
    final dataLength = data.length;
    buffer.addByte((dataLength >> 16) & 0xFF);
    buffer.addByte((dataLength >> 8) & 0xFF);
    buffer.addByte(dataLength & 0xFF);
    buffer.add(data);
    return buffer.toBytes();
  }

  Uint8List _buildCustomMetadataEntry(String mimeType, Uint8List data) {
    final mimeBytes = utf8.encode(mimeType);
    final mimeLength = mimeBytes.length;
    if (mimeLength == 0 || mimeLength > 128) {
      throw ArgumentError('Custom MIME type length must be 1-128: $mimeType');
    }
    final buffer = BytesBuilder();
    buffer.addByte((mimeLength - 1) & 0x7F);
    buffer.add(mimeBytes);
    final dataLength = data.length;
    buffer.addByte((dataLength >> 16) & 0xFF);
    buffer.addByte((dataLength >> 8) & 0xFF);
    buffer.addByte(dataLength & 0xFF);
    buffer.add(data);
    return buffer.toBytes();
  }

  Map<String, dynamic>? _decodeJsonMap(Payload? payload) {
    if (payload == null) return null;
    return _decodeJsonMapFromUtf8(payload.getDataUtf8());
  }

  Map<String, dynamic>? _decodeJsonMapFromUtf8(String? text) {
    if (text == null || text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {'value': decoded};
    } on FormatException {
      return {'value': text};
    }
  }
}
