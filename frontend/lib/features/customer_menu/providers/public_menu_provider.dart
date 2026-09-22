import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/shared/models/public_menu.dart';

/// GET /api/public/menu/:restaurantSlug - no auth required. Uses the
/// same shared dioProvider as the rest of the app; it simply won't have
/// a token attached for an anonymous customer, which is fine since this
/// route doesn't check for one.
///
/// On a 404 (restaurant missing or inactive - the backend deliberately
/// makes these indistinguishable), this throws a DioException same as
/// any other failed request. The screen displays it with the existing
/// apiErrorMessage() helper, which already surfaces the backend's
/// "Restaurant menu is currently unavailable." message directly - no
/// separate exception type needed.
final publicMenuProvider =
    FutureProvider.autoDispose.family<PublicMenu, String>((ref, restaurantSlug) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/public/menu/$restaurantSlug');
  return PublicMenu.fromJson(response.data['data'] as Map<String, dynamic>);
});
