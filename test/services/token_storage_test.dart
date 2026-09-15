import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vote/services/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TokenStorage', () {
    late TokenStorage tokenStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tokenStorage = TokenStorage();
    });

    group('setAccessToken / getAccessToken', () {
      test('stores and retrieves the access token', () async {
        await tokenStorage.setAccessToken('test-access-token');
        final token = await tokenStorage.getAccessToken();
        expect(token, 'test-access-token');
      });

      test('returns null when no access token is stored', () async {
        final token = await tokenStorage.getAccessToken();
        expect(token, isNull);
      });

      test('overwrites existing access token', () async {
        await tokenStorage.setAccessToken('old-token');
        await tokenStorage.setAccessToken('new-token');
        final token = await tokenStorage.getAccessToken();
        expect(token, 'new-token');
      });
    });

    group('setRefreshToken / getRefreshToken', () {
      test('stores and retrieves the refresh token', () async {
        await tokenStorage.setRefreshToken('test-refresh-token');
        final token = await tokenStorage.getRefreshToken();
        expect(token, 'test-refresh-token');
      });

      test('returns null when no refresh token is stored', () async {
        final token = await tokenStorage.getRefreshToken();
        expect(token, isNull);
      });
    });

    group('setUsername / getUsername', () {
      test('stores and retrieves the username', () async {
        await tokenStorage.setUsername('testuser');
        final username = await tokenStorage.getUsername();
        expect(username, 'testuser');
      });

      test('returns null when no username is stored', () async {
        final username = await tokenStorage.getUsername();
        expect(username, isNull);
      });
    });

    group('setEmail / getEmail', () {
      test('stores and retrieves the email', () async {
        await tokenStorage.setEmail('test@example.com');
        final email = await tokenStorage.getEmail();
        expect(email, 'test@example.com');
      });

      test('returns null when no email is stored', () async {
        final email = await tokenStorage.getEmail();
        expect(email, isNull);
      });
    });

    group('setBirthYear / getBirthYear', () {
      test('stores and retrieves the birth year', () async {
        await tokenStorage.setBirthYear(1990);
        final birthYear = await tokenStorage.getBirthYear();
        expect(birthYear, 1990);
      });

      test('returns null when no birth year is stored', () async {
        final birthYear = await tokenStorage.getBirthYear();
        expect(birthYear, isNull);
      });
    });

    group('setGender / getGender', () {
      test('stores and retrieves the gender', () async {
        await tokenStorage.setGender('f');
        final gender = await tokenStorage.getGender();
        expect(gender, 'f');
      });

      test('returns null when no gender is stored', () async {
        final gender = await tokenStorage.getGender();
        expect(gender, isNull);
      });
    });

    group('setNationality / getNationality', () {
      test('stores and retrieves the nationality', () async {
        await tokenStorage.setNationality('US');
        final nationality = await tokenStorage.getNationality();
        expect(nationality, 'US');
      });

      test('returns null when no nationality is stored', () async {
        final nationality = await tokenStorage.getNationality();
        expect(nationality, isNull);
      });
    });

    group('setRegion / getRegion', () {
      test('stores and retrieves the region', () async {
        await tokenStorage.setRegion('California');
        final region = await tokenStorage.getRegion();
        expect(region, 'California');
      });

      test('returns null when no region is stored', () async {
        final region = await tokenStorage.getRegion();
        expect(region, isNull);
      });
    });

    group('setIsAdmin / getIsAdmin', () {
      test('stores and retrieves the admin flag', () async {
        await tokenStorage.setIsAdmin(true);
        final isAdmin = await tokenStorage.getIsAdmin();
        expect(isAdmin, isTrue);
      });

      test('returns false when no admin flag is stored', () async {
        final isAdmin = await tokenStorage.getIsAdmin();
        expect(isAdmin, isFalse);
      });

      test('returns false when explicitly set to false', () async {
        await tokenStorage.setIsAdmin(false);
        final isAdmin = await tokenStorage.getIsAdmin();
        expect(isAdmin, isFalse);
      });
    });

    group('setCategories / getCategories', () {
      test('stores and retrieves the category mapping', () async {
        final categories = {1: 'General', 2: 'Health', 3: 'Environment'};
        await tokenStorage.setCategories(categories);
        final result = await tokenStorage.getCategories();
        expect(result, categories);
      });

      test('returns empty map when no categories are stored', () async {
        final result = await tokenStorage.getCategories();
        expect(result, isEmpty);
      });

      test('returns empty map when stored value is empty string', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('categories', '');
        final result = await tokenStorage.getCategories();
        expect(result, isEmpty);
      });

      test('handles malformed JSON gracefully', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('categories', 'not valid json');
        final result = await tokenStorage.getCategories();
        expect(result, isEmpty);
      });

      test('handles non-map JSON gracefully', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('categories', '["not", "a", "map"]');
        final result = await tokenStorage.getCategories();
        expect(result, isEmpty);
      });

      test('parses string keys to int', () async {
        final categories = {'1': 'One', '2': 'Two'};
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('categories', '{"1": "One", "2": "Two"}');
        final result = await tokenStorage.getCategories();
        expect(result, {1: 'One', 2: 'Two'});
      });

      test('ignores non-string values', () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('categories', '{"1": 123, "2": "valid"}');
        final result = await tokenStorage.getCategories();
        // Non-string values should be filtered out
        expect(result, {2: 'valid'});
      });
    });

    group('clearAll', () {
      test('clears all stored data', () async {
        await tokenStorage.setAccessToken('access');
        await tokenStorage.setRefreshToken('refresh');
        await tokenStorage.setUsername('user');
        await tokenStorage.setEmail('user@example.com');
        await tokenStorage.setBirthYear(1990);
        await tokenStorage.setGender('f');
        await tokenStorage.setNationality('US');
        await tokenStorage.setRegion('CA');
        await tokenStorage.setIsAdmin(true);
        await tokenStorage.setCategories({1: 'Test'});

        await tokenStorage.clearAll();

        expect(await tokenStorage.getAccessToken(), isNull);
        expect(await tokenStorage.getRefreshToken(), isNull);
        expect(await tokenStorage.getUsername(), isNull);
        expect(await tokenStorage.getEmail(), isNull);
        expect(await tokenStorage.getBirthYear(), isNull);
        expect(await tokenStorage.getGender(), isNull);
        expect(await tokenStorage.getNationality(), isNull);
        expect(await tokenStorage.getRegion(), isNull);
        expect(await tokenStorage.getIsAdmin(), isFalse);
        expect(await tokenStorage.getCategories(), isEmpty);
      });
    });

    group('hasTokens', () {
      test('returns true when both tokens are present', () async {
        await tokenStorage.setAccessToken('access');
        await tokenStorage.setRefreshToken('refresh');
        final hasTokens = await tokenStorage.hasTokens();
        expect(hasTokens, isTrue);
      });

      test('returns false when only access token is present', () async {
        await tokenStorage.setAccessToken('access');
        final hasTokens = await tokenStorage.hasTokens();
        expect(hasTokens, isFalse);
      });

      test('returns false when only refresh token is present', () async {
        await tokenStorage.setRefreshToken('refresh');
        final hasTokens = await tokenStorage.hasTokens();
        expect(hasTokens, isFalse);
      });

      test('returns false when no tokens are present', () async {
        final hasTokens = await tokenStorage.hasTokens();
        expect(hasTokens, isFalse);
      });
    });

    group('persistence across instances', () {
      test('data persists across TokenStorage instances', () async {
        await tokenStorage.setAccessToken('persistent-token');
        await tokenStorage.setUsername('persistent-user');
        await tokenStorage.setCategories({42: 'Answer'});

        // Create a new instance
        final newStorage = TokenStorage();

        expect(await newStorage.getAccessToken(), 'persistent-token');
        expect(await newStorage.getUsername(), 'persistent-user');
        expect(await newStorage.getCategories(), {42: 'Answer'});
      });
    });
  });
}
