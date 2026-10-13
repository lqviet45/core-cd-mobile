import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/auth/presentation/lock_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/startup_screens.dart';
import '../../features/certificates/presentation/certificate_screens.dart';
import '../../features/customers/presentation/customer_screens.dart';
import '../../features/customers/presentation/new_customer_screen.dart';
import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/interest/presentation/interest_screen.dart';
import '../../features/lots/presentation/lot_screens.dart';
import '../../features/more/presentation/more_screens.dart';
import '../../features/notifications/presentation/notification_screens.dart';
import '../../features/reports/presentation/report_screens.dart';
import '../../features/trading/presentation/buy_screens.dart';
import '../../features/trading/presentation/sell_screen.dart';
import '../../features/transactions/presentation/transaction_detail_screen.dart';
import '../../features/transactions/presentation/transaction_screens.dart';
import '../auth/app_lock.dart';
import '../auth/providers.dart';
import '../network/connectivity.dart';
import '../ui/widgets.dart';

/// Quyết định điều hướng theo trạng thái đăng nhập và khoá nhanh (hàm thuần để dễ test).
String? redirectFor({
  required AuthState auth,
  required bool locked,
  required String location,
}) {
  const open = {'/login', '/splash', '/lock', '/offline'};
  switch (auth) {
    case AuthRestoring():
      return location == '/splash' ? null : '/splash';
    case AuthOffline():
      return location == '/offline' ? null : '/offline';
    case AuthSignedOut():
      return location == '/login' ? null : '/login';
    case AuthSignedIn():
      if (locked) return location == '/lock' ? null : '/lock';
      return open.contains(location) ? '/home' : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(authControllerProvider, (_, __) => refresh.value++)
    ..listen(appLockProvider, (_, __) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      auth: ref.read(authControllerProvider),
      locked: ref.read(appLockProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/lock', builder: (_, __) => const LockScreen()),
      GoRoute(path: '/offline', builder: (_, __) => const OfflineStartScreen()),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/trade/buy',
        builder: (_, s) => BuyLotScreen(
          customerId: s.uri.queryParameters['customerId'],
          lotId: s.uri.queryParameters['lotId'],
        ),
        routes: [
          GoRoute(path: 'amount', builder: (_, __) => const BuyAmountScreen()),
          GoRoute(path: 'review', builder: (_, __) => const BuyReviewScreen()),
        ],
      ),
      GoRoute(
        path: '/trade/sell',
        builder: (_, s) =>
            SellScreen(customerId: s.uri.queryParameters['customerId']),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/certificates',
                builder: (_, __) => const CertificateListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, s) =>
                        CertificateDetailScreen(id: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (_, __) => const TransactionListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, s) =>
                        TransactionDetailScreen(id: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/customers',
                builder: (_, __) => const CustomerListScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (_, __) => const NewCustomerScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, s) =>
                        CustomerDetailScreen(id: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, __) => const MoreScreen(),
                routes: [
                  GoRoute(
                    path: 'lots',
                    builder: (_, __) => const LotListScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, s) =>
                            LotDetailScreen(id: s.pathParameters['id']!),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'interest',
                    builder: (_, __) => const InterestScreen(),
                  ),
                  GoRoute(
                    path: 'maturities',
                    builder: (_, __) => const MaturitiesScreen(),
                  ),
                  GoRoute(
                    path: 'reports',
                    builder: (_, __) => const ReportsScreen(),
                  ),
                  GoRoute(
                    path: 'status',
                    builder: (_, __) => const StatusScreen(),
                  ),
                  GoRoute(
                    path: 'account',
                    builder: (_, __) => const AccountScreen(),
                  ),
                ],
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

/// Khung điều hướng 5 tab theo thiết kế: Tổng quan · CCTG · Giao dịch · Khách hàng · Thêm.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _items = [
    (LucideIcons.layoutGrid, 'Tổng quan'),
    (LucideIcons.fileText, 'CCTG'),
    (LucideIcons.repeat, 'Giao dịch'),
    (LucideIcons.users, 'Khách hàng'),
    (LucideIcons.menu, 'Thêm'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).value ?? true;
    return Scaffold(
      body: Column(
        children: [
          if (!online) const SafeArea(bottom: false, child: OfflineBanner()),
          Expanded(child: shell),
        ],
      ),
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
}
