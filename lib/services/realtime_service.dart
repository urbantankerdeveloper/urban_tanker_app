import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

class RealtimeEvent {
  const RealtimeEvent(this.name, this.payload);

  final String name;
  final dynamic payload;
}

class RealtimeService {
  RealtimeService({required this.socketUrl, required this.token});

  final String socketUrl;
  final String token;
  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();
  io.Socket? _socket;
  bool _eventListenersRegistered = false;
  bool isConnected = false;

  Stream<RealtimeEvent> get events => _events.stream;

  void connect(void Function(String event, dynamic payload) onEvent) {
    _socket ??= io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .enableReconnection()
          .build(),
    );
    if (_eventListenersRegistered) return;
    _eventListenersRegistered = true;
    _socket!
      ..on('connect', (_) {
        isConnected = true;
      })
      ..on('disconnect', (reason) {
        isConnected = false;
        _events.add(RealtimeEvent('disconnect', reason));
      })
      ..on('connect_error', (error) {
        isConnected = false;
        _events.add(RealtimeEvent('connect_error', error));
      })
      ..onAny((event, payload) {
        _events.add(RealtimeEvent(event, payload));
        onEvent(event, payload);
      });
  }

  void joinBooking(String bookingId) {
    _socket?.emit('booking:join', bookingId);
  }

  void joinVendor(String vendorId) {
    _socket?.emit('vendor:join', vendorId);
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    isConnected = false;
    unawaited(_events.close());
  }
}
