/// Vai trò theo backend: Viewer < Operator < Admin.
enum Role {
  viewer('Viewer', 'Chỉ xem'),
  operator('Operator', 'Nghiệp vụ'),
  admin('Admin', 'Quản trị');

  Role(this.code, this.label);
  final String code;
  final String label;

  static Role parse(String code) => Role.values.firstWhere(
    (r) => r.code == code,
    orElse: () => Role.viewer, // vai trò lạ: quyền thấp nhất
  );

  bool atLeast(Role min) => index >= min.index;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.lastLoginAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'] as String,
    username: j['username'] as String,
    fullName: j['fullName'] as String,
    role: Role.parse(j['role'] as String),
    lastLoginAt: j['lastLoginAt'] == null
        ? null
        : DateTime.parse(j['lastLoginAt'] as String),
  );

  final String id;
  final String username;
  final String fullName;
  final Role role;
  final DateTime? lastLoginAt;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final last = parts.length >= 2 ? parts.sublist(parts.length - 2) : parts;
    return last
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .join()
        .toUpperCase();
  }
}

/// Kết quả đăng nhập/làm mới. `refreshToken` mới thay thế token cũ (xoay vòng, mỗi token dùng một lần).
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.user,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> j) => AuthTokens(
    accessToken: j['accessToken'] as String,
    accessTokenExpiresAt: DateTime.parse(j['accessTokenExpiresAt'] as String),
    refreshToken: j['refreshToken'] as String,
    user: AuthUser.fromJson(j['user'] as Map<String, dynamic>),
  );

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final AuthUser user;
}
