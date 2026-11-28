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
  static const maxReconnectDelayMs = 30000;
  static const _configuredTransports = String.fromEnvironment(
    'SOCKET_TRANSPORTS',
    defaultValue: 'polling',
  );

  final String socketUrl;
  final Future<String?> Function() readToken;
  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();
  final Set<String> _joinedBookings = <String>{};
  io.Socket? _socket;
  Future<void>? _connecting;
  void Function(String event, dynamic payload)? _onEvent;
  bool _eventListenersRegistered = false;
  bool _disposed = false;
  bool isConnected = false;

  Stream<RealtimeEvent> get events => _events.stream;

  void connect(void Function(String event, dynamic payload) onEvent) {
    _onEvent = onEvent;
    if (_disposed || _socket != null || _connecting != null) return;
    final connectionAttempt = _connectWithToken(onEvent);
    _connecting = connectionAttempt;
    unawaited(_finishConnectionAttempt(connectionAttempt));
  }

  Future<void> _connectWithToken(
    void Function(String event, dynamic payload) onEvent,
  ) async {
    final token = await _readUsableToken();
    if (_disposed || token == null) return;

    final transports = _parseTransports(_configuredTransports);
    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(transports)
          .setUpgrade(transports.contains('websocket'))
          // Auth is resolved on every reconnect so a refreshed token is used.
          .setAuthFn((callback) {
            readToken()
                .then((nextToken) {
                  if (_disposed ||
                      nextToken == null ||
                      nextToken.trim().isEmpty) {
                    _socket?.disconnect();
                    return;
                  }
                  callback({'token': nextToken});
                })
                .catchError((Object error) {
                  _emit(RealtimeEvent('connect_error', error));
                  _socket?.disconnect();
                });
          })
          .enableReconnection()
          .setReconnectionAttempts(maxReconnectAttempts)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(maxReconnectDelayMs)
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

  Future<String?> _readUsableToken() async {
    try {
      final token = await readToken();
      if (token == null || token.trim().isEmpty) return null;
      return token;
    } catch (error) {
      _emit(RealtimeEvent('connect_error', error));
      return null;
    }
  }

  Future<void> _finishConnectionAttempt(Future<void> attempt) async {
    try {
      await attempt;
    } catch (error) {
      _emit(RealtimeEvent('connect_error', error));
    } finally {
      if (identical(_connecting, attempt)) _connecting = null;
    }
  }

  static List<String> _parseTransports(String value) {
    final transports = value
        .split(',')
        .map((transport) => transport.trim())
        .toList();
    if (transports.any(
      (transport) => transport != 'polling' && transport != 'websocket',
    )) {
      throw StateError(
        'SOCKET_TRANSPORTS must contain polling and/or websocket',
      );
    }
    if (transports.toSet().length != transports.length) {
      throw StateError('SOCKET_TRANSPORTS must not contain duplicates');
    }
    return transports;
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
    if (socket != null && !socket.connected) {
      socket.connect();
    } else if (socket == null && _onEvent != null) {
      connect(_onEvent!);
    }
  }

  void dispose() {
    _disposed = true;
    _socket?.dispose();
    _socket = null;
    _onEvent = null;
    _eventListenersRegistered = false;
    _joinedBookings.clear();
    isConnected = false;
    unawaited(_events.close());
  }
}
