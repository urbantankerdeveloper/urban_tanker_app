import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

class RealtimeEvent {
  const RealtimeEvent(this.name, this.payload);

  final String name;
  final dynamic payload;
}

class RealtimeService {
  RealtimeService({required this.socketUrl, required this.readToken});

  /// Reconnection stops after this many attempts; the app reconnects on resume.
  static const maxReconnectAttempts = 10;

  final String socketUrl;
  final Future<String?> Function() readToken;
  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();
  final Set<String> _joinedBookings = <String>{};
  io.Socket? _socket;
  bool _eventListenersRegistered = false;
  bool isConnected = false;

  Stream<RealtimeEvent> get events => _events.stream;

  void connect(void Function(String event, dynamic payload) onEvent) {
    _socket ??= io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          // Auth is resolved on every (re)connect so a refreshed token is used.
          .setAuthFn((callback) {
            readToken()
                .then((token) => callback({'token': token ?? ''}))
                .catchError((_) => callback({'token': ''}));
          })
          .enableReconnection()
          .setReconnectionAttempts(maxReconnectAttempts)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(15000)
          .build(),
    );
    if (_eventListenersRegistered) return;
    _eventListenersRegistered = true;
    _socket!
      ..on('connect', (_) {
        isConnected = true;
        // Room membership is lost when the socket drops, so join again.
        for (final bookingId in _joinedBookings) {
          _socket?.emit('booking:join', bookingId);
        }
      })
      ..on('disconnect', (reason) {
        isConnected = false;
        _emit(RealtimeEvent('disconnect', reason));
      })
      ..on('connect_error', (error) {
        isConnected = false;
        _emit(RealtimeEvent('connect_error', error));
      })
      ..onAny((event, payload) {
        _emit(RealtimeEvent(event, payload));
        onEvent(event, payload);
      });
  }

  void _emit(RealtimeEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void joinBooking(String bookingId) {
    _joinedBookings.add(bookingId);
    _socket?.emit('booking:join', bookingId);
  }

  void leaveBooking(String bookingId) {
    _joinedBookings.remove(bookingId);
    _socket?.emit('booking:leave', bookingId);
  }

  void joinVendor(String vendorId) {
    _socket?.emit('vendor:join', vendorId);
  }

  /// Drops the connection while the app is in the background.
  void pause() {
    _socket?.disconnect();
    isConnected = false;
  }

  /// Reconnects when the app returns to the foreground.
  void resume() {
    final socket = _socket;
    if (socket != null && !socket.connected) socket.connect();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _eventListenersRegistered = false;
    _joinedBookings.clear();
    isConnected = false;
    unawaited(_events.close());
  }
}
