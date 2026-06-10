/// Authentication-related data models for the Vote backend.
library;

/// Request body for user registration.
class RegisterRequest {
  final String username;
  final String email;
  final String password;

  const RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'email': email,
        'password': password,
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

  const User({
    required this.id,
    required this.username,
    required this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
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
