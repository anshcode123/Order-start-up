import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/core/network/socket_client.dart';
import 'package:scanserve/core/network/socket_connection_status.dart';
import 'package:scanserve/features/restaurant_admin/providers/order_providers.dart';
import 'package:scanserve/shared/models/restaurant_order.dart';

/// One socket per logged-in Restaurant Admin session, live for as long
/// as something is watching it (see RestaurantAdminScaffold, which
/// watches this for the whole "/dashboard/*" session so it isn't
/// reconnected on every tab switch). autoDispose closes the socket the
/// moment nothing needs it any more - e.g. on logout, when the whole
/// admin shell unmounts (Phase 7 spec #23).
final restaurantOrderSocketProvider =
    StateNotifierProvider.autoDispose<RestaurantOrderSocketNotifier, SocketConnectionStatus>((ref) {
  final notifier = RestaurantOrderSocketNotifier(ref);
  ref.onDispose(notifier.disconnect);
  return notifier;
});

class RestaurantOrderSocketNotifier extends StateNotifier<SocketConnectionStatus> {
  RestaurantOrderSocketNotifier(this._ref) : super(SocketConnectionStatus.connecting) {
    _connect();
  }

  final Ref _ref;
  socket_io.Socket? _socket;

  void _connect() {
    final token = _ref.read(tokenStorageProvider).token;
    if (token == null) {
      // Shouldn't happen on an authenticated route, but fail closed
      // rather than connecting with no auth at all.
      state = SocketConnectionStatus.error;
      return;
    }

    final socket = socket_io.io(
      kSocketBaseUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;

    // onConnect fires on the FIRST connection and on every automatic
    // reconnection alike, so resyncing here (rather than only in a
    // reconnect-specific callback) covers both without depending on a
    // less-certain reconnect event name. REST stays the source of
    // truth - a fresh GET always follows a (re)connect (Phase 7 spec
    // #14).
    socket.onConnect((_) {
      state = SocketConnectionStatus.connected;
      _ref.read(restaurantOrdersProvider.notifier).refresh();
    });

    socket.onDisconnect((_) => state = SocketConnectionStatus.disconnected);
    socket.onConnectError((_) => state = SocketConnectionStatus.error);
    socket.onError((_) => state = SocketConnectionStatus.error);

    socket.on('order:new', (data) {
      if (data is Map) {
        final json = Map<String, dynamic>.from(data);
        final order = RestaurantOrder.fromNewOrderEvent(json);
        _ref.read(restaurantOrdersProvider.notifier).upsertFromNewOrderEvent(json);
        _ref.read(newOrderEventProvider.notifier).state = order;
      }
    });

    socket.on('order:status_updated', (data) {
      if (data is Map) {
        _ref
            .read(restaurantOrdersProvider.notifier)
            .patchStatusFromEvent(Map<String, dynamic>.from(data));
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
