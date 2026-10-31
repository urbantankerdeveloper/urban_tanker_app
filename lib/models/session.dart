enum WorkspaceRole { customer, vendor, dispatcher, admin }

WorkspaceRole roleFromString(String? value) {
  return WorkspaceRole.values.firstWhere(
    (role) => role.name == value,
    orElse: () => WorkspaceRole.customer,
  );
}

class SessionUser {
  const SessionUser({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.email,
    this.themeMode,
  });

  final String? id;
  final String name;
  final String username;
  final WorkspaceRole role;
  final String? email;
  final String? themeMode;

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: json['id'] as String?,
      name: (json['name'] ?? json['email'] ?? 'Urban Tanker user').toString(),
      username: (json['username'] ?? json['email'] ?? '').toString(),
      role: roleFromString(json['role'] as String?),
      email: json['email'] as String?,
      themeMode: json['themeMode'] as String?,
    );
  }
}

class AuthResult {
  const AuthResult({
    required this.user,
    required this.accessToken,
    this.refreshToken,
  });

  final SessionUser user;
  final String accessToken;
  final String? refreshToken;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final token = (json['accessToken'] ?? json['token']) as String?;
    if (token == null || token.isEmpty) {
      throw const FormatException('The server did not return an access token.');
    }
    final user = json['user'];
    if (user is! Map<String, dynamic>) {
      throw const FormatException('The server did not return a user profile.');
    }
    return AuthResult(
      user: SessionUser.fromJson(user),
      accessToken: token,
      refreshToken: json['refreshToken'] as String?,
    );
  }
}
