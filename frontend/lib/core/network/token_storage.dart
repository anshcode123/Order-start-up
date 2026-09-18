import 'package:shared_preferences/shared_preferences.dart';

/// Persists the JWT so a page refresh doesn't log the user out.
/// SharedPreferences keeps values cached in memory after the first
/// load, so `token` reads synchronously once `TokenStorage` has been
/// constructed with an already-awaited instance (see main.dart).
class TokenStorage {
  TokenStorage(this._prefs);

  static const _key = 'scanserve_auth_token';

  final SharedPreferences _prefs;

  String? get token => _prefs.getString(_key);

  Future<void> setToken(String token) => _prefs.setString(_key, token);

  Future<void> clear() => _prefs.remove(_key);
}
