/// Authentication-related data models for the Vote backend.
library;

/// Structured authentication error exposed to the UI so it can be localized.
///
/// [code] selects the localized message template (e.g. `loginFailed`),
/// while [detail] carries the underlying, often server-provided, text that
/// is inserted into the template at display time.
class AuthError {
  final String code;
  final String? detail;

  const AuthError(this.code, [this.detail]);

  @override
  String toString() => 'AuthError($code${detail != null ? ': $detail' : ''})';
}

/// Request body for user registration.
class RegisterRequest {
  final String username;
  final String email;
  final String password;
  final int? birthYear;
  final String? gender;
  final String? nationality;

  const RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
    this.birthYear,
    this.gender,
    this.nationality,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'password': password,
        if (birthYear != null) 'birth_year': birthYear,
        if (gender != null) 'gender': gender,
        if (nationality != null) 'nationality': nationality,
      };
}

/// Request body for user login.
class LoginRequest {
  final String username;
  final String password;

  const LoginRequest({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
      };
}

/// Response from login/refresh endpoints containing JWT tokens.
class AuthResponse {
  final String accessToken;
  final String refreshToken;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }
}

/// Request body for refreshing tokens.
class RefreshRequest {
  final String refreshToken;

  const RefreshRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {
        'refresh_token': refreshToken,
      };
}

/// Request body for logout.
class LogoutRequest {
  final String refreshToken;

  const LogoutRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {
        'refresh_token': refreshToken,
      };
}

/// User model returned after registration.
class User {
  final int id;
  final String username;
  final String email;
  final int? birthYear;
  final String? gender;
  final String? nationality;

  const User({
    required this.id,
    required this.username,
    required this.email,
    this.birthYear,
    this.gender,
    this.nationality,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      birthYear: json['birth_year'] as int?,
      gender: json['gender'] as String?,
      nationality: json['nationality'] as String?,
    );
  }
}

/// Generic error response from the API.
class ApiError {
  final String error;

  const ApiError({required this.error});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(error: json['error'] as String? ?? 'Unknown error');
  }
}
