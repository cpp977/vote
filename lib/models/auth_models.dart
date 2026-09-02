/// Authentication-related data models for the Vote backend.
library;

/// Country model returned by the `GET /countries` endpoint.
class Country {
  final String code;
  final String name;

  const Country({required this.code, required this.name});

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

/// Region model returned by the `GET /regions` endpoint.
class Region {
  final String code;
  final String name;
  final String countryCode;

  const Region({
    required this.code,
    required this.name,
    required this.countryCode,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? '',
    );
  }
}

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
  final String? region;

  const RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
    this.birthYear,
    this.gender,
    this.nationality,
    this.region,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'email': email,
    'password': password,
    if (birthYear != null) 'birth_year': birthYear,
    if (gender != null) 'gender': gender,
    if (nationality != null) 'nationality': nationality,
    if (region != null) 'region': region,
  };
}

/// Request body for user login.
class LoginRequest {
  final String username;
  final String password;

  const LoginRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() => {'username': username, 'password': password};
}

/// Request body for the forgot-password endpoint.
///
/// The backend always returns the same generic response regardless of
/// whether the email exists, preventing user enumeration.
class ForgotPasswordRequest {
  final String email;

  const ForgotPasswordRequest({required this.email});

  Map<String, dynamic> toJson() => {'email': email};
}

/// Response from the forgot-password endpoint.
///
/// The message is intentionally generic — it does not reveal whether the
/// email belongs to an account in the system.
class ForgotPasswordResponse {
  final String message;

  const ForgotPasswordResponse({required this.message});

  factory ForgotPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResponse(message: json['message'] as String? ?? '');
  }
}

/// Request body for the reset-password endpoint.
///
/// [token] is the raw (un-hashed) token received from the email link.
/// [password] is the user's new password (minimum 8 characters per backend).
class ResetPasswordRequest {
  final String token;
  final String password;

  const ResetPasswordRequest({required this.token, required this.password});

  Map<String, dynamic> toJson() => {'token': token, 'password': password};
}

/// Response from login/refresh endpoints containing JWT tokens.
class AuthResponse {
  final String accessToken;
  final String refreshToken;

  const AuthResponse({required this.accessToken, required this.refreshToken});

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

  Map<String, dynamic> toJson() => {'refresh_token': refreshToken};
}

/// Request body for logout.
class LogoutRequest {
  final String refreshToken;

  const LogoutRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {'refresh_token': refreshToken};
}

/// User model returned after registration.
class User {
  final String id;
  final String username;
  final String email;
  final int? birthYear;
  final String? gender;
  final String? nationality;
  final String? region;
  final bool isAdmin;
  final bool isActive;

  const User({
    required this.id,
    required this.username,
    required this.email,
    this.birthYear,
    this.gender,
    this.nationality,
    this.region,
    this.isAdmin = false,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      birthYear: json['birth_year'] as int?,
      gender: json['gender'] as String?,
      nationality: json['nationality'] as String?,
      region: json['region'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Request body for updating the authenticated user's own profile via
/// `PATCH`/`PUT` `/me`.
///
/// Only `email`, `gender`, `password`, `nationality` and `region` are
/// modifiable; `username` is the user's identity and is never sent.
/// Fields are omitted from the JSON when `null` so that only the changed
/// fields are transmitted (the backend accepts partial updates). To clear a
/// nullable field, explicitly pass `null`.
class UpdateUserRequest {
  final String email;
  final String? gender;
  final String? password;
  final String? nationality;
  final String? region;

  const UpdateUserRequest({
    required this.email,
    this.gender,
    this.password,
    this.nationality,
    this.region,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    if (gender != null) 'gender': gender,
    if (password != null) 'password': password,
    if (nationality != null) 'nationality': nationality,
    if (region != null) 'region': region,
  };
}

/// Generic error response from the API.
class ApiError {
  final String error;

  const ApiError({required this.error});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(error: json['error'] as String? ?? 'Unknown error');
  }
}
