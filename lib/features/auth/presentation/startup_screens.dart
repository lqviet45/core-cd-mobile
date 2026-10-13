import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/ui/widgets.dart';

/// Hiển thị trong lúc khôi phục phiên khi mở app.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ),
    ),
  );
}

/// Mở app nhưng không xác định được phiên vì mất mạng (refresh token vẫn được giữ nguyên).
class OfflineStartScreen extends ConsumerWidget {
  const OfflineStartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Column(
      children: [
        Expanded(
          child: ErrorState(
            error: const ApiException(
              status: 0,
              message: 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
            ),
            onRetry: () =>
                ref.read(authControllerProvider.notifier).retryRestore(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: const Text('Đăng xuất'),
          ),
        ),
      ],
    ),
  );
}
