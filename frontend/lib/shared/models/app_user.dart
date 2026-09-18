/// The logged-in user, as returned by POST /api/auth/login and
/// GET /api/auth/me. `restaurant` is only populated for a
/// RESTAURANT_ADMIN - null for SUPER_ADMIN.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.restaurantId,
    this.restaurantName,
    this.restaurantSlug,
  });

  final String id;
  final String name;
  final String email;
  final String role; // 'SUPER_ADMIN' | 'RESTAURANT_ADMIN'
  final String? restaurantId;
  final String? restaurantName;
  final String? restaurantSlug;

  bool get isSuperAdmin => role == 'SUPER_ADMIN';
  bool get isRestaurantAdmin => role == 'RESTAURANT_ADMIN';

  /// Parses the shape returned by POST /api/auth/login, where
  /// `restaurant` (if present) is just an id string.
  factory AppUser.fromLoginJson(Map<String, dynamic> json) {
    final restaurant = json['restaurant'];
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      restaurantId: restaurant is String ? restaurant : null,
    );
  }

  /// Parses the shape returned by GET /api/auth/me, where `restaurant`
  /// (if present) is an object with id/name/slug.
  factory AppUser.fromMeJson(Map<String, dynamic> json) {
    final restaurant = json['restaurant'] as Map<String, dynamic>?;
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      restaurantId: restaurant?['id'] as String?,
      restaurantName: restaurant?['name'] as String?,
      restaurantSlug: restaurant?['slug'] as String?,
    );
  }
}
