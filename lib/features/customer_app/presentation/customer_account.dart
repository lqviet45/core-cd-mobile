import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/providers.dart';
import '../../../core/utils/text.dart';
import 'customer_providers.dart';
import 'kh_theme.dart';
import 'kh_widgets.dart';

/// K08 – Tài khoản: hồ sơ (do ngân hàng quản lý), bảo mật (sinh trắc, đổi mật khẩu), lịch sử giao dịch, đăng xuất.
class CustomerAccountScreen extends ConsumerWidget {
  const CustomerAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kh;
    final profile = ref.watch(custProfileProvider);
    return Scaffold(
      body: Column(
        children: [
          const KhTopBar(height: 56),
          const KhLargeTitle('Tài khoản'),
          Expanded(
            child: profile.when(
              loading: () => const KhSkeleton(rows: 2),
              error: (e, _) => KhError(
                error: e,
                onRetry: () => ref.invalidate(custProfileProvider),
              ),
              data: (p) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  KhCard(
                    child: Row(
                      children: [
                        KhAvatar(initialsOf(p.fullName)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.fullName,
                                style: KhType.t2.copyWith(color: k.ink),
                              ),
                              Text(
                                'Mã khách hàng ${p.cif}',
                                style: KhType.s.copyWith(color: k.ink2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  KhList(
                    children: [
                      KhInfoRow('Điện thoại', p.phoneMasked, minHeight: 52),
                      KhInfoRow('Email', p.emailMasked, minHeight: 52),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
                    child: Text(
                      'Thông tin do ngân hàng quản lý. Cần thay đổi, vui lòng liên hệ chuyên viên.',
                      style: KhType.c.copyWith(color: k.ink3),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const KhGroupLabel('Bảo mật'),
                  const SizedBox(height: 10),
                  KhList(
                    children: [
                      const _BiometricRow(),
                      KhRow(
                        minHeight: 56,
                        title: 'Đổi mật khẩu',
                        trailing: Icon(
                          LucideIcons.chevronRight,
                          size: 20,
                          color: k.ink3,
                        ),
                        onTap: () => context.push('/password'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  KhButton(
                    label: 'Lịch sử giao dịch',
                    icon: LucideIcons.history,
                    kind: KhButtonKind.outlined,
                    height: 48,
                    onPressed: () => context.push('/transactions'),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => _confirmLogout(context, ref),
                      child: Text(
                        'Đăng xuất',
                        style: TextStyle(
                          color: k.bad,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ cần mật khẩu để đăng nhập lại.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Đăng xuất',
              style: TextStyle(color: ctx.kh.bad, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(custAuthControllerProvider.notifier).logout();
    }
  }
}

/// Công tắc "Mở khoá bằng vân tay / Face ID". Bật phải xác thực ngay một lần để chắc chắn dùng được.
class _BiometricRow extends ConsumerWidget {
  const _BiometricRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(custBiometricPrefProvider) ?? false;
    final available = ref.watch(custBiometricAvailableProvider).value ?? false;
    return KhRow(
      minHeight: 56,
      title: 'Mở khóa bằng vân tay / Face ID',
      subtitle: available
          ? null
          : 'Thiết bị chưa cài sinh trắc hoặc khoá màn hình',
      trailing: Semantics(
        label: 'Mở khóa bằng vân tay hoặc Face ID',
        child: Switch(
          value: on && available,
          onChanged: available
              ? (v) async {
                  final pref = ref.read(custBiometricPrefProvider.notifier);
                  if (!v) {
                    await pref.set(false);
                    return;
                  }
                  final ok = await ref
                      .read(biometricProvider)
                      .authenticate('Xác thực để bật mở khoá nhanh');
                  if (ok) await pref.set(true);
                }
              : null,
        ),
      ),
    );
  }
}
