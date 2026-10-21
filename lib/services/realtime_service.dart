import 'package:socket_io_client/socket_io_client.dart' as io;

class RealtimeService {
  RealtimeService({required this.socketUrl, required this.token});

  final String socketUrl;
  final String token;
  io.Socket? _socket;

  void connect(void Function(String event, dynamic payload) onEvent) {
    _socket ??= io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .enableReconnection()
          .build(),
    );
    _socket!.onAny(onEvent);
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
  }
}
