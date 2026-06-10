import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting authentication tokens locally.
class TokenStorage {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _usernameKey = 'username';

  /// Stores the access token.
  Future<void> setAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }

  /// Retrieves the stored access token, or null if not set.
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  /// Stores the refresh token.
  Future<void> setRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  /// Retrieves the stored refresh token, or null if not set.
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  /// Stores the username of the logged-in user.
  Future<void> setUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  /// Retrieves the stored username, or null if not set.
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  /// Clears all stored authentication data.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_usernameKey);
  }

  /// Checks if both tokens are present.
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    return accessToken != null && refreshToken != null;
  }
}
