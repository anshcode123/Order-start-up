class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? restaurant;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.restaurant,
  });

  bool get isSuperAdmin => role == 'SUPER_ADMIN';
  bool get isRestaurantAdmin => role == 'RESTAURANT_ADMIN';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      restaurant: json['restaurant'] is String
          ? json['restaurant'] as String
          : (json['restaurant'] is Map
              ? (json['restaurant']['_id'] as String?)
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'restaurant': restaurant,
    };
  }
}
