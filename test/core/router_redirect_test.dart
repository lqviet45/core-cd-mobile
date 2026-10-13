import 'package:core_cd_mobile/core/auth/auth_models.dart';
import 'package:core_cd_mobile/core/auth/providers.dart';
import 'package:core_cd_mobile/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AuthUser(
    id: '1',
    username: 'admin',
    fullName: 'Quản trị viên',
    role: Role.admin,
  );
  String? go(AuthState a, String loc, {bool locked = false}) =>
      redirectFor(auth: a, locked: locked, location: loc);

  test('đang khôi phục → splash', () {
    expect(go(const AuthRestoring(), '/home'), '/splash');
    expect(go(const AuthRestoring(), '/splash'), isNull);
  });

  test('chưa đăng nhập → login', () {
    expect(go(const AuthSignedOut(), '/home'), '/login');
    expect(go(const AuthSignedOut(), '/login'), isNull);
  });

  test('mất mạng khi khởi động → offline', () {
    expect(go(const AuthOffline(), '/home'), '/offline');
    expect(go(const AuthOffline(), '/offline'), isNull);
  });

  test('đã đăng nhập: rời các màn mở về /home, giữ nguyên màn khác', () {
    expect(go(const AuthSignedIn(user), '/login'), '/home');
    expect(go(const AuthSignedIn(user), '/splash'), '/home');
    expect(go(const AuthSignedIn(user), '/customers'), isNull);
  });

  test('đang khoá → mọi đường dẫn về /lock', () {
    expect(go(const AuthSignedIn(user), '/customers', locked: true), '/lock');
    expect(go(const AuthSignedIn(user), '/lock', locked: true), isNull);
  });
}
