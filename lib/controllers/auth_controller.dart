import 'package:flutter/foundation.dart';
import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

/// Controller for managing authentication state.
///
/// Uses [ChangeNotifier] to notify listeners of state changes.
class AuthController extends ChangeNotifier {
  final AuthService _authService;
  final TokenStorage _tokenStorage;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _username;

  AuthController({
    AuthService? authService,
    TokenStorage? tokenStorage,
  })  : _authService = authService ?? AuthService(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  /// Whether a user is currently authenticated.
  bool get isAuthenticated => _isAuthenticated;

  /// Whether an authentication operation is in progress.
  bool get isLoading => _isLoading;

  /// The current error message, if any.
  String? get errorMessage => _errorMessage;

  /// The username of the currently logged-in user.
  String? get username => _username;

  /// Checks if the user has valid stored tokens.
  /// Should be called on app startup.
  Future<void> checkAuthStatus() async {
    _setLoading(true);
    try {
      final hasTokens = await _tokenStorage.hasTokens();
      if (hasTokens) {
        _username = await _tokenStorage.getUsername();
        _isAuthenticated = true;
      } else {
        _isAuthenticated = false;
      }
    } catch (_) {
      _isAuthenticated = false;
    } finally {
      _setLoading(false);
    }
  }

  /// Registers a new user account.
  /// Returns true on success, false on failure.
  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final request = RegisterRequest(
        username: username,
        email: email,
        password: password,
      );

      await _authService.register(request);
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Registration failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Logs in a user with the given credentials.
  /// Returns true on success, false on failure.
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final request = LoginRequest(
        username: username,
        password: password,
      );

      final response = await _authService.login(request);

      await _tokenStorage.setAccessToken(response.accessToken);
      await _tokenStorage.setRefreshToken(response.refreshToken);
      await _tokenStorage.setUsername(username);

      _username = username;
      _isAuthenticated = true;
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Login failed: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Logs out the current user.
  /// Clears all stored tokens regardless of API response.
  Future<void> logout() async {
    _setLoading(true);

    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      final accessToken = await _tokenStorage.getAccessToken();

      if (refreshToken != null && accessToken != null) {
        final request = LogoutRequest(refreshToken: refreshToken);
        await _authService.logout(request, accessToken);
      }
    } catch (e) {
      // Log the error but continue with local logout
      debugPrint('Logout API error: $e');
    } finally {
      await _tokenStorage.clearAll();
      _isAuthenticated = false;
      _username = null;
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Clears the current error message.
  void clearError() {
    _clearError();
    notifyListeners();
  }
}
