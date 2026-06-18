import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class WebSocketClient with WidgetsBindingObserver {
  final String baseUrl;
  io.Socket? _socket;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  int _retryDelay = 1;
  bool _disposed = false;
  String? _token;

  WebSocketClient({required this.baseUrl});

  Stream<Map<String, dynamic>> get events => _controller.stream;

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  void connect(String token) {
    _token = token;
    _retryDelay = 1;
    _connect();
  }

  void _connect() {
    if (_disposed) return;
    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $_token'})
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..onConnect((_) => _retryDelay = 1)
      ..on('notification', (data) {
        if (data is Map) _controller.add(data.cast<String, dynamic>());
      })
      ..onDisconnect((_) => _scheduleReconnect())
      ..onError((_) => _scheduleReconnect())
      ..connect();
  }

  void _scheduleReconnect() {
    if (_disposed || _token == null) return;
    Future.delayed(Duration(seconds: _retryDelay), () {
      if (!_disposed) {
        _retryDelay = (_retryDelay * 2).clamp(1, 32);
        _connect();
      }
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    _disposed = true;
    if (WidgetsBinding.instance.lifecycleState != null) {
      WidgetsBinding.instance.removeObserver(this);
    }
    disconnect();
    _controller.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _token != null) {
      _connect();
    } else if (state == AppLifecycleState.paused) {
      disconnect();
    }
  }
}
