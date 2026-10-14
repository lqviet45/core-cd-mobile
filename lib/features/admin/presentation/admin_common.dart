import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_models.dart';
import '../../../core/auth/providers.dart';
import '../../../core/ui/widgets.dart';

/// Người dùng hiện tại là Admin? (API cũng chặn; đây chỉ để ẩn/hiện và chặn mở màn bằng đường dẫn.)
final isAdminProvider = Provider<bool>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is AuthSignedIn && auth.user.role == Role.admin;
});

/// Bọc màn chỉ dành cho Admin.
class AdminOnly extends ConsumerWidget {
  const AdminOnly({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isAdminProvider)) return child;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const EmptyState(
        icon: Icons.lock_outline,
        title: 'Chỉ dành cho quản trị viên',
        message: 'Liên hệ quản trị viên nếu bạn cần quyền này.',
      ),
    );
  }
}

/// Khung chung cho form dạng tờ phủ (bottom sheet) có bàn phím: cuộn được, không bị bàn phím che.
Future<T?> showAdminSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheet).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: child,
        ),
      ),
    );
