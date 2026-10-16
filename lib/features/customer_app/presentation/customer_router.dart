import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/providers.dart';
import '../../../core/network/api_exception.dart';
import 'customer_account.dart';
import 'customer_calendar.dart';
import 'customer_certs.dart';
import 'customer_home.dart';
import 'customer_login_screen.dart';
import 'customer_password_screen.dart';
import 'customer_providers.dart';
import 'customer_transactions.dart';
import 'kh_widgets.dart';

/// Điều hướng theo trạng thái đăng nhập (hàm thuần để dễ test). Còn mật khẩu tạm → chỉ được ở màn đổi mật khẩu.
String? customerRedirectFor({
  required AuthState auth,
  required bool mustChangePassword,
  required String location,
}) {
  const open = {'/login', '/splash', '/offline', '/change-password'};
  switch (auth) {
    case AuthRestoring():
      return location == '/splash' ? null : '/splash';
    case AuthOffline():
      return location == '/offline' ? null : '/offline';
    case AuthSignedOut():
      return location == '/login' ? null : '/login';
    case AuthSignedIn():
      if (mustChangePassword) {
        return location == '/change-password' ? null : '/change-password';
      }
      return open.contains(location) ? '/home' : null;
  }
}

final customerRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(custAuthControllerProvider, (_, __) => refresh.value++)
    ..listen(custMustChangeProvider, (_, __) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => customerRedirectFor(
      auth: ref.read(custAuthControllerProvider),
      mustChangePassword: ref.read(custMustChangeProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _Splash()),
      GoRoute(path: '/login', builder: (_, __) => const CustomerLoginScreen()),
      GoRoute(path: '/offline', builder: (_, __) => const _OfflineStart()),
      GoRoute(
        path: '/change-password',
        builder: (_, __) => const CustomerPasswordScreen(forced: true),
      ),
      GoRoute(
        path: '/password',
        builder: (_, __) => const CustomerPasswordScreen(),
      ),
      GoRoute(
        path: '/certificate/:id',
        builder: (_, s) =>
            CustomerCertificateDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/transactions',
        builder: (_, __) => const CustomerTransactionsScreen(),
      ),
      GoRoute(
        path: '/transaction/:id',
        builder: (_, s) =>
            CustomerTransactionDetailScreen(id: s.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const CustomerHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/certificates',
                builder: (_, __) => const CustomerCertificatesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (_, __) => const CustomerCalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (_, __) => const CustomerAccountScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  static const _items = [
    KhNavItem(LucideIcons.house, 'Trang chủ'),
    KhNavItem(LucideIcons.fileText, 'CCTG'),
    KhNavItem(LucideIcons.calendar, 'Lịch'),
    KhNavItem(LucideIcons.user, 'Tài khoản'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: KhNavBar(
      items: _items,
      index: shell.currentIndex,
      onSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
    ),
  );
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.landmark, size: 48),
          SizedBox(height: 24),
          CircularProgressIndicator(),
        ],
      ),
    ),
  );
}

/// Mở app nhưng không xác định được phiên vì mất mạng (refresh token vẫn được giữ).
class _OfflineStart extends ConsumerWidget {
  const _OfflineStart();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: KhError(
      error: const ApiException(
        status: 0,
        message: 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      ),
      onRetry: () =>
          ref.read(custAuthControllerProvider.notifier).retryRestore(),
    ),
  );
}
