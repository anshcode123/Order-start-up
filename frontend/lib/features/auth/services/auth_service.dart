import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanserve/core/constants/api_constants.dart';
import 'package:scanserve/features/auth/models/user_model.dart';

class AuthResult {
  final UserModel user;
  final String token;

  AuthResult({required this.user, required this.token});
}

class AuthService {
  final Dio _dio;

  AuthService(this._dio);

  static const String _tokenKey = 'scanserve_auth_token';
  static const String _userKey = 'scanserve_auth_user';

  /// Performs POST /api/auth/login with email and password
  Future<AuthResult> login(String email, String password) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final userData = data['user'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userData);

      // Save token and user into SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(user.toJson()));

      return AuthResult(user: user, token: token);
    } on DioException catch (e) {
      if (e.response != null) {
        final message =
            e.response?.data is Map && e.response?.data['message'] != null
                ? e.response?.data['message'] as String
                : 'Authentication failed. Please check your credentials.';
        throw Exception(message);
      } else {
        throw Exception(
            'Server unavailable or network error. Please try again.');
      }
    } catch (e) {
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  /// Restores session from SharedPreferences on app startup
  Future<AuthResult?> getStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final userStr = prefs.getString(_userKey);

      if (token == null ||
          token.isEmpty ||
          userStr == null ||
          userStr.isEmpty) {
        return null;
      }

      final userJson = jsonDecode(userStr) as Map<String, dynamic>;
      final user = UserModel.fromJson(userJson);

      return AuthResult(user: user, token: token);
    } catch (_) {
      await logout();
      return null;
    }
  }

  /// Removes token and user from SharedPreferences
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
