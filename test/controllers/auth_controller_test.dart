import 'package:flutter_test/flutter_test.dart';
import 'package:vote/controllers/auth_controller.dart';
import 'package:vote/models/auth_models.dart';
import 'package:vote/models/category_models.dart';
import 'package:vote/services/auth_service.dart';
import 'package:vote/services/token_storage.dart';

void main() {
  group('AuthController', () {
    late FakeAuthService authService;
    late FakeTokenStorage tokenStorage;
    late AuthController controller;

    setUp(() {
      authService = FakeAuthService();
      tokenStorage = FakeTokenStorage();
      controller = AuthController(
        authService: authService,
        tokenStorage: tokenStorage,
      );
    });

    // ── checkAuthStatus ──────────────────────

    group('checkAuthStatus', () {
      test('sets isAuthenticated when tokens exist', () async {
        tokenStorage.hasTokensResult = true;
        tokenStorage.usernameResult = 'alice';
        tokenStorage.emailResult = 'alice@example.com';
        tokenStorage.birthYearResult = 1990;
        tokenStorage.genderResult = 'f';
        tokenStorage.nationalityResult = 'US';
        tokenStorage.isAdminResult = false;
        tokenStorage.categoriesResult = {1: 'General'};

        await controller.checkAuthStatus();

        expect(controller.isAuthenticated, isTrue);
        expect(controller.username, 'alice');
        expect(controller.email, 'alice@example.com');
        expect(controller.birthYear, 1990);
        expect(controller.gender, 'f');
        expect(controller.nationality, 'US');
        expect(controller.isAdmin, isFalse);
        expect(controller.categories, {1: 'General'});
        expect(controller.isLoading, isFalse);
      });

      test('sets isAuthenticated to false when no tokens exist', () async {
        tokenStorage.hasTokensResult = false;

        await controller.checkAuthStatus();

        expect(controller.isAuthenticated, isFalse);
        expect(controller.isLoading, isFalse);
      });

      test('sets isAuthenticated to false when token check throws', () async {
        tokenStorage.hasTokensResult = true;
        tokenStorage.hasTokensThrows = true;

        await controller.checkAuthStatus();

        expect(controller.isAuthenticated, isFalse);
        expect(controller.isLoading, isFalse);
      });

      test('keeps empty categories when fetch fails', () async {
        tokenStorage.hasTokensResult = false;
        authService.categoriesThrows = true;

        await controller.checkAuthStatus();

        expect(controller.categories, isEmpty);
      });

      test('sets isLoading during the operation', () async {
        tokenStorage.hasTokensResult = false;
        authService.categoriesResult = [
          const Category(id: 1, name: 'General', language: 'en'),
        ];

        final future = controller.checkAuthStatus();
        expect(controller.isLoading, isTrue);
        await future;
        expect(controller.isLoading, isFalse);
      });
    });

    // ── login ────────────────────────────────

    group('login', () {
      test('returns true on successful login', () async {
        authService.loginResult = const AuthResponse(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        );
        authService.currentUserResult = const User(
          id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          username: 'alice',
          email: 'alice@example.com',
          birthYear: 1990,
          gender: 'f',
          nationality: 'US',
          isAdmin: false,
        );
        authService.categoriesResult = [
          const Category(id: 1, name: 'General', language: 'en'),
        ];

        final result = await controller.login(
          username: 'alice',
          password: 'secret',
        );

        expect(result, isTrue);
        expect(controller.isAuthenticated, isTrue);
        expect(controller.username, 'alice');
        expect(controller.email, 'alice@example.com');
        expect(controller.birthYear, 1990);
        expect(controller.gender, 'f');
        expect(controller.nationality, 'US');
        expect(controller.isAdmin, isFalse);
        expect(controller.isLoading, isFalse);
        expect(controller.error, isNull);
      });

      test('returns false on ApiException', () async {
        authService.loginThrows = true;
        authService.loginException = const ApiException(
          'Invalid credentials',
          401,
        );

        final result = await controller.login(
          username: 'alice',
          password: 'wrong',
        );

        expect(result, isFalse);
        expect(controller.isAuthenticated, isFalse);
        expect(controller.isLoading, isFalse);
        expect(controller.error, isNotNull);
      });

      test('returns false on unexpected exception', () async {
        authService.loginThrows = true;
        authService.loginException = Exception('Network error');

        final result = await controller.login(
          username: 'alice',
          password: 'secret',
        );

        expect(result, isFalse);
        expect(controller.error?.code, 'loginFailed');
      });

      test('stores tokens and username on successful login', () async {
        authService.loginResult = const AuthResponse(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        );
        authService.currentUserResult = const User(
          id: 'b2c3d4e5-f6a7-8901-bcde-f12345678901',
          username: 'bob',
          email: 'bob@example.com',
          isAdmin: true,
        );
        authService.categoriesResult = [];

        await controller.login(username: 'bob', password: 'secret');

        expect(tokenStorage.accessTokenStored, 'access-token');
        expect(tokenStorage.refreshTokenStored, 'refresh-token');
        expect(tokenStorage.usernameStored, 'bob');
        expect(tokenStorage.isAdminStored, isTrue);
      });

      test('handles missing profile data gracefully', () async {
        authService.loginResult = const AuthResponse(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        );
        authService.currentUserResult = const User(
          id: 'c3d4e5f6-a7b8-9012-cdef-123456789012',
          username: 'minimal',
          email: '',
          isAdmin: false,
        );
        authService.currentUserThrows = true;

        final result = await controller.login(
          username: 'minimal',
          password: 'secret',
        );

        expect(result, isTrue);
        expect(controller.isAuthenticated, isTrue);
        expect(controller.username, 'minimal');
        expect(controller.email, isNull);
        expect(controller.birthYear, isNull);
      });

      test('sets isLoading during login', () async {
        authService.loginResult = const AuthResponse(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        );
        authService.currentUserResult = const User(
          id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          username: 'alice',
          email: 'alice@example.com',
          isAdmin: false,
        );
        authService.categoriesResult = [
          const Category(id: 1, name: 'General', language: 'en'),
        ];

        final future = controller.login(username: 'alice', password: 'secret');
        expect(controller.isLoading, isTrue);
        await future;
        expect(controller.isLoading, isFalse);
      });
    });

    // ── register ─────────────────────────────

    group('register', () {
      test('returns true on successful registration', () async {
        authService.registerResult = const User(
          id: 'd4e5f6a7-b8c9-0123-defa-123456789012',
          username: 'newuser',
          email: 'new@example.com',
          isAdmin: false,
        );

        final result = await controller.register(
          username: 'newuser',
          email: 'new@example.com',
          password: 'secret123',
        );

        expect(result, isTrue);
        expect(controller.isLoading, isFalse);
        expect(controller.error, isNull);
      });

      test('returns false on ApiException', () async {
        authService.registerThrows = true;
        authService.registerException = const ApiException(
          'Username already taken',
          409,
        );

        final result = await controller.register(
          username: 'existing',
          email: 'existing@example.com',
          password: 'secret123',
        );

        expect(result, isFalse);
        expect(controller.isLoading, isFalse);
        expect(controller.error, isNotNull);
      });

      test('returns false on unexpected exception', () async {
        authService.registerThrows = true;
        authService.registerException = Exception('Network error');

        final result = await controller.register(
          username: 'newuser',
          email: 'new@example.com',
          password: 'secret123',
        );

        expect(result, isFalse);
        expect(controller.error?.code, 'registrationFailed');
      });

      test('passes optional fields to RegisterRequest', () async {
        authService.registerResult = const User(
          id: 'd4e5f6a7-b8c9-0123-defa-123456789012',
          username: 'fulluser',
          email: 'full@example.com',
          isAdmin: false,
        );

        await controller.register(
          username: 'fulluser',
          email: 'full@example.com',
          password: 'secret123',
          birthYear: 1995,
          gender: 'm',
          nationality: 'DE',
        );

        final request = authService.lastRegisterRequest!;
        expect(request.birthYear, 1995);
        expect(request.gender, 'm');
        expect(request.nationality, 'DE');
      });

      test('sets isLoading during registration', () async {
        authService.registerResult = const User(
          id: 'd4e5f6a7-b8c9-0123-defa-123456789012',
          username: 'newuser',
          email: 'new@example.com',
          isAdmin: false,
        );

        final future = controller.register(
          username: 'newuser',
          email: 'new@example.com',
          password: 'secret123',
        );
        expect(controller.isLoading, isTrue);
        await future;
        expect(controller.isLoading, isFalse);
      });
    });

    // ── logout ───────────────────────────────

    group('logout', () {
      test('clears all tokens and resets state', () async {
        tokenStorage.accessTokenResult = 'old-access';
        tokenStorage.refreshTokenResult = 'old-refresh';

        await controller.logout();

        expect(controller.isAuthenticated, isFalse);
        expect(controller.username, isNull);
        expect(controller.email, isNull);
        expect(controller.birthYear, isNull);
        expect(controller.gender, isNull);
        expect(controller.nationality, isNull);
        expect(controller.isAdmin, isFalse);
        expect(controller.categories, isEmpty);
        expect(controller.isLoading, isFalse);
        expect(tokenStorage.clearedAll, isTrue);
      });

      test('continues logout when API call throws', () async {
        tokenStorage.accessTokenResult = 'old-access';
        tokenStorage.refreshTokenResult = 'old-refresh';
        authService.logoutThrows = true;

        await controller.logout();

        expect(controller.isAuthenticated, isFalse);
        expect(tokenStorage.clearedAll, isTrue);
      });

      test('sets showLoginPage when requested', () async {
        tokenStorage.accessTokenResult = null;
        tokenStorage.refreshTokenResult = null;

        await controller.logout(showLoginPage: true);

        expect(controller.showLoginPage, isTrue);
      });

      test('sets isLoading during logout', () async {
        tokenStorage.accessTokenResult = null;
        tokenStorage.refreshTokenResult = null;

        final future = controller.logout();
        expect(controller.isLoading, isTrue);
        await future;
        expect(controller.isLoading, isFalse);
      });
    });

    // ── updateUser ───────────────────────────

    group('updateUser', () {
      test('returns true on successful update', () async {
        authService.updateCurrentUserResult = const User(
          id: 'e5f6a7b8-c9d0-1234-ef56-a7b8c9d0e1f2',
          username: 'alice',
          email: 'updated@example.com',
          gender: 'f',
          isAdmin: false,
        );
        tokenStorage.accessTokenResult = 'token';

        final result = await controller.updateUser(
          const UpdateUserRequest(email: 'updated@example.com', gender: 'f'),
        );

        expect(result, isTrue);
        expect(controller.email, 'updated@example.com');
        expect(controller.gender, 'f');
        expect(controller.isLoading, isFalse);
        expect(controller.error, isNull);
      });

      test('returns false when not authenticated', () async {
        tokenStorage.accessTokenResult = null;

        final result = await controller.updateUser(
          const UpdateUserRequest(email: 'new@example.com'),
        );

        expect(result, isFalse);
        expect(controller.error?.code, 'profileUpdateFailed');
        expect(controller.isLoading, isFalse);
      });

      test('returns false on ApiException', () async {
        authService.updateCurrentUserThrows = true;
        authService.updateCurrentUserException = const ApiException(
          'Invalid email',
          400,
        );
        tokenStorage.accessTokenResult = 'token';

        final result = await controller.updateUser(
          const UpdateUserRequest(email: 'bad-email'),
        );

        expect(result, isFalse);
        expect(controller.error, isNotNull);
        expect(controller.isLoading, isFalse);
      });

      test('persists updated fields to token storage', () async {
        authService.updateCurrentUserResult = const User(
          id: 'f6a7b8c9-d0e1-2345-6a7b-8c9d0e1f2a3b',
          username: 'alice',
          email: 'persisted@example.com',
          gender: 'm',
          isAdmin: true,
        );
        tokenStorage.accessTokenResult = 'token';

        await controller.updateUser(
          const UpdateUserRequest(email: 'persisted@example.com', gender: 'm'),
        );

        expect(tokenStorage.emailStored, 'persisted@example.com');
        expect(tokenStorage.genderStored, 'm');
        expect(tokenStorage.isAdminStored, isTrue);
      });
    });

    // ── loadUserDetails ──────────────────────

    group('loadUserDetails', () {
      test('returns true and updates fields on success', () async {
        authService.currentUserResult = const User(
          id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          username: 'alice',
          email: 'alice@example.com',
          birthYear: 1990,
          gender: 'f',
          nationality: 'US',
          isAdmin: false,
        );
        tokenStorage.accessTokenResult = 'token';

        final result = await controller.loadUserDetails();

        expect(result, isTrue);
        expect(controller.username, 'alice');
        expect(controller.email, 'alice@example.com');
        expect(controller.birthYear, 1990);
        expect(controller.gender, 'f');
        expect(controller.nationality, 'US');
      });

      test('returns false when no access token', () async {
        tokenStorage.accessTokenResult = null;

        final result = await controller.loadUserDetails();

        expect(result, isFalse);
      });

      test('returns false when API call fails', () async {
        authService.currentUserThrows = true;
        authService.currentUserException = const ApiException('Not found', 404);
        tokenStorage.accessTokenResult = 'token';

        final result = await controller.loadUserDetails();

        expect(result, isFalse);
      });
    });

    // ── clearError ───────────────────────────

    test('clearError resets the error to null', () {
      controller.clearError();
      expect(controller.error, isNull);
    });
  });
}

// ── Fake implementations ──────────────────────────────────────────────────────

class FakeAuthService extends AuthService {
  AuthResponse? loginResult;
  Exception? loginException;
  bool loginThrows = false;

  User? registerResult;
  Exception? registerException;
  bool registerThrows = false;
  RegisterRequest? lastRegisterRequest;

  User? currentUserResult;
  Exception? currentUserException;
  bool currentUserThrows = false;

  User? updateCurrentUserResult;
  Exception? updateCurrentUserException;
  bool updateCurrentUserThrows = false;

  List<Category> categoriesResult = [];
  bool categoriesThrows = false;

  @override
  Future<User> register(RegisterRequest request) async {
    lastRegisterRequest = request;
    if (registerThrows) throw registerException!;
    return registerResult ?? User(id: '00000000-0000-0000-0000-000000000000', username: '', email: '');
  }

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    if (loginThrows) throw loginException!;
    return loginResult ?? const AuthResponse(accessToken: '', refreshToken: '');
  }

  @override
  Future<void> logout(LogoutRequest request, String accessToken) async {
    if (logoutThrows) throw Exception('Logout failed');
  }

  bool logoutThrows = false;

  @override
  Future<AuthResponse> refresh(RefreshRequest request) async {
    if (loginThrows) throw loginException!;
    return loginResult ?? const AuthResponse(accessToken: '', refreshToken: '');
  }

  @override
  Future<User> getCurrentUser(String accessToken) async {
    if (currentUserThrows) throw currentUserException!;
    return currentUserResult ?? User(id: '00000000-0000-0000-0000-000000000000', username: '', email: '');
  }

  @override
  Future<User> updateCurrentUser(
    String accessToken,
    UpdateUserRequest request,
  ) async {
    if (updateCurrentUserThrows) throw updateCurrentUserException!;
    return updateCurrentUserResult ?? User(id: '00000000-0000-0000-0000-000000000000', username: '', email: '');
  }

  @override
  Future<List<Category>> getCategories(
    String languageCode, {
    String? accessToken,
  }) async {
    if (categoriesThrows) throw Exception('Categories failed');
    return categoriesResult;
  }
}

class FakeTokenStorage extends TokenStorage {
  String? accessTokenResult;
  String? refreshTokenResult;
  String? usernameResult;
  String? emailResult;
  int? birthYearResult;
  String? genderResult;
  String? nationalityResult;
  bool isAdminResult = false;
  Map<int, String> categoriesResult = {};
  bool hasTokensResult = false;
  bool hasTokensThrows = false;

  String? accessTokenStored;
  String? refreshTokenStored;
  String? usernameStored;
  String? emailStored;
  int? birthYearStored;
  String? genderStored;
  String? nationalityStored;
  bool? isAdminStored;
  Map<int, String>? categoriesStored;
  bool clearedAll = false;

  @override
  Future<String?> getAccessToken() async => accessTokenResult;

  @override
  Future<String?> getRefreshToken() async => refreshTokenResult;

  @override
  Future<String?> getUsername() async => usernameResult;

  @override
  Future<String?> getEmail() async => emailResult;

  @override
  Future<int?> getBirthYear() async => birthYearResult;

  @override
  Future<String?> getGender() async => genderResult;

  @override
  Future<String?> getNationality() async => nationalityResult;

  @override
  Future<bool> getIsAdmin() async => isAdminResult;

  @override
  Future<Map<int, String>> getCategories() async => categoriesResult;

  @override
  Future<bool> hasTokens() async {
    if (hasTokensThrows) throw Exception('Token check failed');
    return hasTokensResult;
  }

  @override
  Future<void> setAccessToken(String token) async {
    accessTokenStored = token;
  }

  @override
  Future<void> setRefreshToken(String token) async {
    refreshTokenStored = token;
  }

  @override
  Future<void> setUsername(String username) async {
    usernameStored = username;
  }

  @override
  Future<void> setEmail(String email) async {
    emailStored = email;
  }

  @override
  Future<void> setBirthYear(int birthYear) async {
    birthYearStored = birthYear;
  }

  @override
  Future<void> setGender(String gender) async {
    genderStored = gender;
  }

  @override
  Future<void> setNationality(String nationality) async {
    nationalityStored = nationality;
  }

  @override
  Future<void> setIsAdmin(bool isAdmin) async {
    isAdminStored = isAdmin;
  }

  @override
  Future<void> setCategories(Map<int, String> categories) async {
    categoriesStored = categories;
  }

  @override
  Future<void> clearAll() async {
    clearedAll = true;
  }
}
