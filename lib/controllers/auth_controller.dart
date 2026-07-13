import 'package:flutter/widgets.dart';
import '../models/auth_models.dart';
import '../l10n/auth_error_localization.dart';
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
  AuthError? _error;
  String? _username;
  String? _email;
  int? _birthYear;
  String? _gender;
  String? _nationality;
  Map<int, String> _categories = {};

  AuthController({AuthService? authService, TokenStorage? tokenStorage})
    : _authService = authService ?? AuthService(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  /// Whether a user is currently authenticated.
  bool get isAuthenticated => _isAuthenticated;

  /// Whether an authentication operation is in progress.
  bool get isLoading => _isLoading;

  /// The current authentication error, if any. UI code localizes it via the
  /// [localizedAuthError] helper using the [AuthError.code] and [detail].
  AuthError? get error => _error;

  /// The username of the currently logged-in user.
  String? get username => _username;

  /// The email address of the currently logged-in user.
  String? get email => _email;

  /// The birth year of the currently logged-in user.
  int? get birthYear => _birthYear;

  /// The gender of the currently logged-in user.
  String? get gender => _gender;

  /// The nationality of the currently logged-in user.
  String? get nationality => _nationality;

  /// The available question categories as a mapping of category id to name.
  Map<int, String> get categories => _categories;

  /// Checks if the user has valid stored tokens.
  /// Should be called on app startup.
  Future<void> checkAuthStatus() async {
    _setLoading(true);
    try {
      final hasTokens = await _tokenStorage.hasTokens();
      if (hasTokens) {
        _username = await _tokenStorage.getUsername();
        _email = await _tokenStorage.getEmail();
        _birthYear = await _tokenStorage.getBirthYear();
        _gender = await _tokenStorage.getGender();
        _nationality = await _tokenStorage.getNationality();
        _categories = await _tokenStorage.getCategories();
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
    int? birthYear,
    String? gender,
    String? nationality,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final request = RegisterRequest(
        username: username,
        email: email,
        password: password,
        birthYear: birthYear,
        gender: gender,
        nationality: nationality,
      );

      await _authService.register(request);
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(_errorFromApi(e));
      _setLoading(false);
      return false;
    } catch (_) {
      _setError(const AuthError('registrationFailed', null));
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
      final request = LoginRequest(username: username, password: password);

      final response = await _authService.login(request);

      await _tokenStorage.setAccessToken(response.accessToken);
      await _tokenStorage.setRefreshToken(response.refreshToken);
      await _tokenStorage.setUsername(username);

      _username = username;

      // Fetch user profile data (username, email, birth year, gender,
      // nationality) so the account-details screen has everything it needs.
      try {
        final user = await _authService.getCurrentUser(response.accessToken);
        _username = user.username;
        _email = user.email;
        _birthYear = user.birthYear;
        _gender = user.gender;
        _nationality = user.nationality;
        if (_username != null) {
          await _tokenStorage.setUsername(_username!);
        }
        if (_email != null) {
          await _tokenStorage.setEmail(_email!);
        }
        if (_birthYear != null) {
          await _tokenStorage.setBirthYear(_birthYear!);
        }
        if (_gender != null) {
          await _tokenStorage.setGender(_gender!);
        }
        if (_nationality != null) {
          await _tokenStorage.setNationality(_nationality!);
        }
      } catch (_) {
        // Profile fetch failed — demographics will be null
      }

      // Fetch the available categories (category id -> name mapping) in the
      // user's current locale so the category filter matches the language of
      // the questions loaded by the home screen.
      try {
        final languageCode =
            WidgetsBinding.instance.platformDispatcher.locale.languageCode;
        final cats = await _authService.getCategories(
          response.accessToken,
          languageCode,
        );
        final map = <int, String>{for (final c in cats) c.id: c.name};
        _categories = map;
        await _tokenStorage.setCategories(map);
      } catch (_) {
        // Category fetch failed — the mapping stays empty; the user can still
        // browse questions without a category filter.
      }

      _isAuthenticated = true;
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(_errorFromApi(e));
      _setLoading(false);
      return false;
    } catch (_) {
      _setError(const AuthError('loginFailed', null));
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
      _email = null;
      _birthYear = null;
      _gender = null;
      _nationality = null;
      _categories = {};
      _setLoading(false);
    }
  }

  /// Fetches the current user's profile from the backend (`/me`) and refreshes
  /// the locally cached details (username, email, birth year, gender and
  /// nationality).
  ///
  /// This is used by the account-details screen to populate fields that were
  /// not available when an older session was restored from storage (e.g. the
  /// email address).
  ///
  /// Returns `true` if the profile was successfully loaded, `false` otherwise.
  /// Errors are swallowed so the UI can fall back to already-stored values.
  Future<bool> loadUserDetails() async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      return false;
    }
    try {
      final user = await _authService.getCurrentUser(accessToken);
      _username = user.username;
      _email = user.email;
      _birthYear = user.birthYear;
      _gender = user.gender;
      _nationality = user.nationality;
      if (_username != null) {
        await _tokenStorage.setUsername(_username!);
      }
      if (_email != null) {
        await _tokenStorage.setEmail(_email!);
      }
      if (_birthYear != null) {
        await _tokenStorage.setBirthYear(_birthYear!);
      }
      if (_gender != null) {
        await _tokenStorage.setGender(_gender!);
      }
      if (_nationality != null) {
        await _tokenStorage.setNationality(_nationality!);
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Maps an [ApiException] to a localizable [AuthError].
  AuthError _errorFromApi(ApiException e) {
    if (e.code == 'requestFailed') {
      return AuthError('requestFailed', e.statusCode.toString());
    }
    return AuthError('server', e.message);
  }

  void _setError(AuthError error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  /// Clears the current error message.
  void clearError() {
    _clearError();
    notifyListeners();
  }
}
