import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_lock.dart';
import '../../../core/auth/pin_providers.dart';
import '../../../core/auth/pin_service.dart';
import '../../../core/auth/providers.dart';
import '../../../core/ui/pin_pad.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/text.dart';

/// Màn khoá nhanh. Nếu tài khoản đã đặt PIN: bàn phím PIN 6 số (kèm phím vân tay nếu thiết bị có). Chưa đặt PIN:
/// chỉ xác thực sinh trắc/mã khoá thiết bị. Luôn có lối ra là đăng nhập lại bằng mật khẩu.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _failed = false;
  bool _busy = false;
  String? _pinError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoPrompt());
  }

  /// Tự bật hộp thoại sinh trắc khi vừa hiện màn khoá; ở chế độ PIN chỉ bật nếu thiết bị có sinh trắc.
  Future<void> _autoPrompt() async {
    final pin = await ref.read(pinEnabledProvider.future);
    if (!mounted) return;
    if (pin && !await ref.read(biometricProvider).isAvailable()) return;
    if (mounted) await _unlock();
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await ref.read(appLockProvider.notifier).unlock();
    if (mounted) {
      setState(() {
        _busy = false;
        _failed = !ok;
      });
    }
  }

  Future<void> _onPin(String pin) async {
    final r = await ref.read(appLockProvider.notifier).unlockWithPin(pin);
    if (!mounted) return;
    setState(() {
      _pinError = switch (r) {
        PinOk() => null,
        PinWrong(:final attemptsLeft) =>
          'Sai mã PIN. Còn $attemptsLeft lần thử.',
        PinLockedOut() =>
          'Nhập sai quá nhiều lần. Vui lòng đăng nhập lại bằng mật khẩu.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPin = ref.watch(pinEnabledProvider).value ?? false;
    final bioAvailable = ref.watch(_bioAvailableProvider).value ?? false;
    return PopScope(
      canPop: false, // không cho thoát khỏi màn khoá bằng nút Back
      child: Scaffold(
        body: SafeArea(
          child: hasPin
              ? _pinBody(context, bioAvailable)
              : _legacyBody(context),
        ),
      ),
    );
  }

  Widget _pinBody(BuildContext context, bool bioAvailable) {
    final auth = ref.watch(authControllerProvider);
    final name = auth is AuthSignedIn ? auth.user.fullName : '';
    final first = name.trim().isEmpty
        ? ''
        : name.trim().split(RegExp(r'\s+')).last;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: FittedBox(child: Lead(text: initialsOf(name))),
            ),
            const SizedBox(height: 16),
            Text(
              first.isEmpty ? 'Chào mừng trở lại' : 'Chào mừng trở lại, $first',
              style: context.text.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              bioAvailable
                  ? 'Nhập mã PIN hoặc dùng vân tay để mở khoá'
                  : 'Nhập mã PIN để mở khoá',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            PinEntry(
              onCompleted: _onPin,
              error: _pinError,
              onBiometric: bioAvailable ? _unlock : null,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              child: const Text('Đăng nhập bằng mật khẩu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legacyBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Ứng dụng đã khoá',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _failed
                  ? 'Xác thực không thành công. Thử lại để mở khoá.'
                  : 'Xác thực bằng sinh trắc hoặc mã khoá thiết bị.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _failed ? scheme.error : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _unlock,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Mở khoá'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      ),
    );
  }
}

final _bioAvailableProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(biometricProvider).isAvailable(),
);
