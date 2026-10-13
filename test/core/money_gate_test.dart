import 'package:core_cd_mobile/core/auth/auth_models.dart';
import 'package:core_cd_mobile/core/auth/providers.dart';
import 'package:core_cd_mobile/core/money/money_gate.dart';
import 'package:core_cd_mobile/core/network/connectivity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart' show FakeBiometric;

class _SignedIn extends AuthController {
  _SignedIn(this.role);
  final Role role;

  @override
  AuthState build() => AuthSignedIn(
    AuthUser(id: '1', username: 'u', fullName: 'Người Dùng', role: role),
  );
}

Future<ProviderContainer> _container({
  Role role = Role.operator,
  bool online = true,
  required FakeBiometric bio,
}) async {
  final c = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(() => _SignedIn(role)),
      isOnlineProvider.overrideWith((ref) => Stream.value(online)),
      biometricProvider.overrideWithValue(bio),
    ],
  );
  addTearDown(c.dispose);
  c.listen(isOnlineProvider, (_, _) {});
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return c;
}

void main() {
  test('đủ điều kiện → xác thực đúng một lần và cho phép', () async {
    final bio = FakeBiometric();
    final c = await _container(bio: bio);
    expect(await c.read(moneyGateProvider).authorize('x'), GateResult.ok);
    expect(bio.prompts, 1);
  });

  test('Viewer bị chặn và KHÔNG hiện hộp thoại xác thực', () async {
    final bio = FakeBiometric();
    final c = await _container(role: Role.viewer, bio: bio);
    expect(
      await c.read(moneyGateProvider).authorize('x'),
      GateResult.forbidden,
    );
    expect(c.read(canWriteProvider), isFalse);
    expect(bio.prompts, 0);
  });

  test('offline bị chặn trước khi xác thực', () async {
    final bio = FakeBiometric();
    final c = await _container(online: false, bio: bio);
    expect(await c.read(moneyGateProvider).authorize('x'), GateResult.offline);
    expect(bio.prompts, 0);
  });

  test(
    'thiết bị không có khoá màn hình → từ chối (không cho qua mặc định)',
    () async {
      final bio = FakeBiometric(available: false);
      final c = await _container(bio: bio);
      expect(
        await c.read(moneyGateProvider).authorize('x'),
        GateResult.noDeviceLock,
      );
      expect(bio.prompts, 0);
    },
  );

  test(
    'người dùng huỷ/sai → denied; mỗi lần gọi đều phải xác thực lại',
    () async {
      final bio = FakeBiometric(passes: false);
      final c = await _container(bio: bio);
      final gate = c.read(moneyGateProvider);
      expect(await gate.authorize('x'), GateResult.denied);
      bio.passes = true;
      expect(await gate.authorize('x'), GateResult.ok);
      expect(await gate.authorize('x'), GateResult.ok);
      expect(bio.prompts, 3, reason: 'không lưu kết quả xác thực để dùng lại');
    },
  );

  test('Operator và Admin đều được ghi', () async {
    for (final r in [Role.operator, Role.admin]) {
      final c = await _container(role: r, bio: FakeBiometric());
      expect(c.read(canWriteProvider), isTrue, reason: '$r');
    }
  });
}
