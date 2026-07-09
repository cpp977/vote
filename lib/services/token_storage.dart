import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting authentication tokens and user profile data locally.
class TokenStorage {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _usernameKey = 'username';
  static const String _birthYearKey = 'birth_year';
  static const String _genderKey = 'gender';
  static const String _nationalityKey = 'nationality';
  static const String _categoriesKey = 'categories';

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

  /// Stores the user's birth year.
  Future<void> setBirthYear(int birthYear) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_birthYearKey, birthYear);
  }

  /// Retrieves the stored birth year, or null if not set.
  Future<int?> getBirthYear() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_birthYearKey);
  }

  /// Stores the user's gender.
  Future<void> setGender(String gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_genderKey, gender);
  }

  /// Retrieves the stored gender, or null if not set.
  Future<String?> getGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_genderKey);
  }

  /// Stores the user's nationality.
  Future<void> setNationality(String nationality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nationalityKey, nationality);
  }

  /// Retrieves the stored nationality, or null if not set.
  Future<String?> getNationality() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nationalityKey);
  }

  /// Stores the available categories as a mapping of category id to name.
  Future<void> setCategories(Map<int, String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_categoriesKey, jsonEncode(categories));
  }

  /// Retrieves the stored category mapping (category id -> name), or an empty
  /// map if none has been stored yet.
  Future<Map<int, String>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_categoriesKey);
    if (raw == null || raw.isEmpty) {
      return <int, String>{};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(int.parse(key), value as String),
      );
    } catch (_) {
      return <int, String>{};
    }
  }

  /// Clears all stored authentication data.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_birthYearKey);
    await prefs.remove(_genderKey);
    await prefs.remove(_nationalityKey);
    await prefs.remove(_categoriesKey);
  }

  /// Checks if both tokens are present.
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    return accessToken != null && refreshToken != null;
  }
}
