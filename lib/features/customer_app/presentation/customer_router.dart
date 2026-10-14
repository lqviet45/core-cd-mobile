import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/ui/widgets.dart';
import 'customer_login_screen.dart';
import 'customer_providers.dart';
import 'customer_screens.dart';

/// Điều hướng theo trạng thái đăng nhập (hàm thuần để dễ test).
String? customerRedirectFor({
  required AuthState auth,
  required String location,
}) {
  const open = {'/login', '/splash', '/offline'};
  switch (auth) {
    case AuthRestoring():
      return location == '/splash' ? null : '/splash';
    case AuthOffline():
      return location == '/offline' ? null : '/offline';
    case AuthSignedOut():
      return location == '/login' ? null : '/login';
    case AuthSignedIn():
      return open.contains(location) ? '/home' : null;
  }
}

final customerRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(custAuthControllerProvider, (_, __) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => customerRedirectFor(
      auth: ref.read(custAuthControllerProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _Splash()),
      GoRoute(path: '/login', builder: (_, __) => const CustomerLoginScreen()),
      GoRoute(path: '/offline', builder: (_, __) => const _OfflineStart()),
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
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, s) => CustomerCertificateDetailScreen(
                      id: s.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (_, __) => const CustomerTransactionsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, s) => CustomerTransactionDetailScreen(
                      id: s.pathParameters['id']!,
                    ),
                  ),
                ],
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
    (LucideIcons.layoutGrid, 'Tổng quan'),
    (LucideIcons.fileText, 'CCTG'),
    (LucideIcons.repeat, 'Giao dịch'),
    (LucideIcons.user, 'Tài khoản'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      destinations: [
        for (final (icon, label) in _items)
          NavigationDestination(icon: Icon(icon), label: label),
      ],
    ),
  );
}

class _Splash extends StatelessWidget {
  const _Splash();

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

/// Mở app nhưng không xác định được phiên vì mất mạng (refresh token vẫn được giữ).
class _OfflineStart extends ConsumerWidget {
  const _OfflineStart();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: ErrorState(
      error: const ApiException(
        status: 0,
        message: 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
      ),
      onRetry: () =>
          ref.read(custAuthControllerProvider.notifier).retryRestore(),
    ),
  );
}
