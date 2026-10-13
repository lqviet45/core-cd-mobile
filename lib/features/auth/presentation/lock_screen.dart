import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_lock.dart';
import '../../../core/auth/providers.dart';

/// Màn khoá nhanh: tự bật hộp thoại sinh trắc khi hiện ra; có nút thử lại và đăng xuất.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false, // không cho thoát khỏi màn khoá bằng nút Back
      child: Scaffold(
        body: SafeArea(
          child: Center(
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
          ),
        ),
      ),
    );
  }
}
