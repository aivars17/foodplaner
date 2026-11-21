import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'document_store.dart';

/// Talks to the Go sync server: pushes local changes, and receives remote
/// changes over a websocket (with periodic HTTP polling as a fallback).
class SyncClient {
  final Dio _dio;
  final String baseUrl; // e.g. http://192.168.1.10:8080
  final SyncClientOptions options;

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _pollTimer;
  bool _connected = false;
  String _lastSync = '';

  /// Remote changes arriving from the server.
  final StreamController<DocChange> _remoteChanges =
      StreamController<DocChange>.broadcast();
  Stream<DocChange> get remoteChanges => _remoteChanges.stream;

  bool get isConnected => _connected;

  SyncClient({
    required this.baseUrl,
    SyncClientOptions? options,
    Dio? dio,
  })  : _dio = dio ?? Dio(),
        options = options ?? const SyncClientOptions();

  void connect() {
    _openSocket();
    _pollTimer = Timer.periodic(options.pollInterval, (_) => _poll());
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _pollTimer?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _connected = false;
  }

  void _openSocket() {
    final uri = Uri.parse(_toWs(baseUrl));
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      _onMessage,
      onError: (_) => _scheduleReconnect(),
      onDone: () => _scheduleReconnect(),
      cancelOnError: true,
    );
    _connected = true;
  }

  void _onMessage(dynamic data) {
    try {
      final j = jsonDecode(data as String);
      if (j['type'] == 'change' && j['change'] != null) {
        _remoteChanges.add(DocChange.fromJson(
          Map<String, dynamic>.from(j['change'] as Map),
        ));
      }
    } catch (_) {
      // ignore malformed messages
    }
  }

  /// Push a change (with its data) to the server.
  Future<void> push(DocChange change, {DocEntity? entity}) async {
    final body = <String, dynamic>{
      'op': change.op,
      'type': change.type,
      'id': change.id,
      'updatedAt': change.updatedAt,
      'version': change.version,
      if (entity != null) 'data': entity.data,
    };
    try {
      await _dio.post<Map<String, dynamic>>(
        '${baseUrl}/api/sync/push',
        data: body,
      );
    } catch (_) {
      // will be retried on next poll/push cycle
    }
  }

  Future<void> _poll() async {
    if (_connected) return; // ws is handling it
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '${baseUrl}/api/sync/changes?since=${Uri.encodeQueryComponent(_lastSync)}',
      );
      final changes = resp.data?['changes'] as List? ?? const [];
      for (final c in changes) {
        final ch =
            DocChange.fromJson(Map<String, dynamic>.from(c as Map));
        _lastSync = ch.updatedAt;
        _remoteChanges.add(ch);
      }
    } catch (_) {
      // ignore, retry next tick
    }
  }

  void _scheduleReconnect() {
    _connected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(options.reconnectInterval, () {
      if (!_connected) _openSocket();
    });
  }

  String _toWs(String httpUrl) {
    final u = Uri.parse(httpUrl);
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    final path = u.path.isEmpty ? '/api/ws' : u.path + '/api/ws';
    final port = u.hasPort ? u.port.toString() : '';
    return '$scheme://${u.host}$path';
  }

  Future<void> close() async {
    await disconnect();
    await _remoteChanges.close();
  }
}

class SyncClientOptions {
  final Duration pollInterval;
  final Duration reconnectInterval;
  const SyncClientOptions({
    this.pollInterval = const Duration(seconds: 5),
    this.reconnectInterval = const Duration(seconds: 3),
  });
}
