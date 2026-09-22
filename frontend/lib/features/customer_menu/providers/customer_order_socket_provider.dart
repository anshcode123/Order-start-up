import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:scanserve/core/network/socket_client.dart';
import 'package:scanserve/core/network/socket_connection_status.dart';
import 'package:scanserve/features/customer_menu/providers/public_order_status_provider.dart';

/// One socket per order-status screen, scoped to a single order's
/// public token. No JWT at all - customers are always anonymous (Phase
/// 7 spec #18). Room membership is granted server-side only after it
/// confirms the token maps to a real order (see backend/lib/socket.js),
/// never assumed client-side.
final customerOrderSocketProvider = StateNotifierProvider.autoDispose
    .family<CustomerOrderSocketNotifier, SocketConnectionStatus, String>((ref, orderRef) {
  final notifier = CustomerOrderSocketNotifier(ref, orderRef);
  ref.onDispose(notifier.disconnect);
  return notifier;
});

class CustomerOrderSocketNotifier extends StateNotifier<SocketConnectionStatus> {
  CustomerOrderSocketNotifier(this._ref, this.orderRef)
      : super(SocketConnectionStatus.connecting) {
    _connect();
  }

  final Ref _ref;
  final String orderRef;
  socket_io.Socket? _socket;

  void _connect() {
    final socket = socket_io.io(
      kSocketBaseUrl,
      socket_io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );
    _socket = socket;

    // Fires on the first connect AND every automatic reconnect alike -
    // re-joining the room and re-syncing via REST on every one of them
    // is what keeps this correct after a dropped connection, without
    // depending on a separate (less certain) reconnect-only event name.
    // Room membership does not survive a disconnect, so this must
    // re-subscribe every time, not just once (Phase 7 spec #14).
    socket.onConnect((_) {
      state = SocketConnectionStatus.connected;
      socket.emit('order:subscribe', {'orderToken': orderRef});
      _ref.read(publicOrderStatusProvider(orderRef).notifier).refresh();
    });

    socket.onDisconnect((_) => state = SocketConnectionStatus.disconnected);
    socket.onConnectError((_) => state = SocketConnectionStatus.error);
    socket.onError((_) => state = SocketConnectionStatus.error);

    socket.on('order:status_updated', (data) {
      if (data is Map) {
        _ref
            .read(publicOrderStatusProvider(orderRef).notifier)
            .applyRealtimeUpdate(Map<String, dynamic>.from(data));
      }
    });

    socket.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
