import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/auth_models.dart';
import '../../../core/auth/providers.dart';
import '../../../core/money/money_gate.dart';
import '../../../core/network/api_call.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/connectivity.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/labels.dart';
import '../../../core/utils/text.dart';
import '../../admin/presentation/admin_common.dart';
import '../../dashboard/presentation/providers.dart';
import 'settings_sections.dart';

/// M23 – Tab "Thêm".
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final maturing =
        ref.watch(dashboardProvider).value?.maturing7DaysCount ?? 0;
    return Scaffold(
      body: Column(
        children: [
          const BigHeader('Thêm'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                AppCard(
                  kind: CardKind.outlined,
                  onTap: () => context.push('/more/account'),
                  child: Row(
                    children: [
                      Lead(text: initialsOf(user.fullName)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: context.text.titleMedium,
                            ),
                            Text(
                              '@${user.username} · ${user.role.label}',
                              style: context.text.bodySmall?.copyWith(
                                color: context.scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.chevronRight,
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
                const SectionHeader('Nghiệp vụ'),
                const SizedBox(height: 8),
                ListGroup(
                  children: [
                    ListRow(
                      lead: const Lead(square: true, icon: LucideIcons.layers),
                      title: 'Đợt phát hành / Lô CD',
                      chevron: true,
                      onTap: () => context.push('/more/lots'),
                    ),
                    ListRow(
                      lead: const Lead(
                        square: true,
                        icon: LucideIcons.calendar,
                      ),
                      title: 'Lịch đáo hạn',
                      trailing: maturing > 0
                          ? StatusChip((label: '$maturing', tone: Tone.warning))
                          : null,
                      chevron: true,
                      onTap: () => context.push('/more/maturities'),
                    ),
                    if (ref.watch(canWriteProvider))
                      ListRow(
                        lead: const Lead(square: true, icon: LucideIcons.coins),
                        title: 'Chi lãi định kỳ',
                        chevron: true,
                        onTap: () => context.push('/more/interest'),
                      ),
                    ListRow(
                      lead: const Lead(square: true, icon: LucideIcons.percent),
                      title: 'Chính sách lãi suất',
                      chevron: true,
                      onTap: () => context.push('/more/rates'),
                    ),
                    ListRow(
                      lead: const Lead(
                        square: true,
                        icon: LucideIcons.chartColumn,
                      ),
                      title: 'Báo cáo',
                      chevron: true,
                      onTap: () => context.push('/more/reports'),
                    ),
                  ],
                ),
                if (ref.watch(isAdminProvider)) ...[
                  const SectionHeader('Quản trị (chỉ Admin)'),
                  const SizedBox(height: 8),
                  ListGroup(
                    children: [
                      ListRow(
                        lead: const Lead(square: true, icon: LucideIcons.users),
                        title: 'Người dùng',
                        chevron: true,
                        onTap: () => context.push('/more/admin/users'),
                      ),
                      ListRow(
                        lead: const Lead(
                          square: true,
                          icon: LucideIcons.history,
                        ),
                        title: 'Nhật ký thao tác',
                        chevron: true,
                        onTap: () => context.push('/more/admin/audit'),
                      ),
                    ],
                  ),
                ],
                const SectionHeader('Hệ thống'),
                const SizedBox(height: 8),
                ListGroup(
                  children: [
                    ListRow(
                      lead: const Lead(square: true, icon: LucideIcons.bell),
                      title: 'Thông báo',
                      chevron: true,
                      onTap: () => context.push('/notifications'),
                    ),
                    ListRow(
                      lead: const Lead(
                        square: true,
                        icon: LucideIcons.activity,
                      ),
                      title: 'Trạng thái hệ thống',
                      chevron: true,
                      onTap: () => context.push('/more/status'),
                    ),
                    ListRow(
                      lead: const Lead(
                        square: true,
                        icon: LucideIcons.settings,
                      ),
                      title: 'Tài khoản & bảo mật',
                      chevron: true,
                      onTap: () => context.push('/more/account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Phiên đăng nhập của chính người dùng.
class SessionInfo {
  const SessionInfo({
    required this.id,
    required this.deviceName,
    required this.lastActiveAt,
  });
  factory SessionInfo.fromJson(Map<String, dynamic> j) => SessionInfo(
    id: j['id'] as String,
    deviceName: j['deviceName'] as String?,
    lastActiveAt: DateTime.parse(j['lastActiveAt'] as String),
  );
  final String id;
  final String? deviceName;
  final DateTime lastActiveAt;
}

final sessionsProvider = FutureProvider.autoDispose<List<SessionInfo>>((ref) {
  final dio = ref.watch(dioProvider);
  return apiCall(() async {
    final res = await dio.get<List<dynamic>>('/api/auth/sessions');
    return res.data!
        .map((e) => SessionInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  });
});

/// M24 – Tài khoản & bảo mật (bản rút gọn: thông tin, khoá nhanh, thiết bị đang đăng nhập, đăng xuất).
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final sessions = ref.watch(sessionsProvider);
    final lockable = ref.watch(_lockAvailableProvider);

    Future<void> logout() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Đăng xuất?'),
          content: const Text('Bạn cần đăng nhập lại để tiếp tục sử dụng.'),
          actions: [
            TextButton(onPressed: () => c.pop(false), child: const Text('Huỷ')),
            TextButton(
              onPressed: () => c.pop(true),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      );
      if (ok ?? false) await ref.read(authControllerProvider.notifier).logout();
    }

    Future<void> revokeOthers() async {
      try {
        final store = ref.read(tokenStoreProvider);
        final token = await store.readRefreshToken();
        final res = await apiCall(
          () => ref
              .read(dioProvider)
              .post<Map<String, dynamic>>(
                '/api/auth/sessions/revoke-others',
                data: {'refreshToken': token},
              ),
        );
        ref.invalidate(sessionsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã đăng xuất ${res.data!['revoked']} thiết bị khác',
              ),
            ),
          );
        }
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản & bảo mật')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: FittedBox(child: Lead(text: initialsOf(user.fullName))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: context.text.titleLarge),
                    Text(
                      '@${user.username} · ${user.role.label}',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SectionHeader('Bảo mật'),
          const SizedBox(height: 8),
          SecuritySettings(lockable: lockable.value ?? false),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Đăng nhập gần nhất: ${formatDateTime(user.lastLoginAt)}. Thao tác tiền luôn yêu cầu xác thực riêng, '
              'kể cả khi tắt khoá nhanh.',
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (lockable.value == false)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                'Thiết bị chưa đặt khoá màn hình/sinh trắc nên không thể bật khoá nhanh và các thao tác tiền sẽ bị từ chối.',
                style: context.text.bodySmall?.copyWith(
                  color: context.scheme.error,
                ),
              ),
            ),
          const SectionHeader('Giao diện'),
          const SizedBox(height: 8),
          const AppearanceSettings(),
          const SectionHeader('Thông báo'),
          const SizedBox(height: 8),
          const NotificationSettings(),
          SectionHeader(
            'Thiết bị đang đăng nhập${sessions.value == null ? '' : ' (${sessions.value!.length})'}',
          ),
          const SizedBox(height: 8),
          sessions.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AppCard(
              kind: CardKind.outlined,
              child: Text(
                'Không tải được danh sách thiết bị.',
                style: TextStyle(color: context.scheme.error),
              ),
            ),
            data: (list) => Column(
              children: [
                ListGroup(
                  children: [
                    for (final s in list)
                      ListRow(
                        lead: const Lead(
                          square: true,
                          icon: LucideIcons.smartphone,
                        ),
                        title: s.deviceName ?? 'Thiết bị không rõ',
                        subtitle: 'Hoạt động ${formatDateTime(s.lastActiveAt)}',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: list.length > 1 ? revokeOthers : null,
                    icon: const Icon(LucideIcons.logOut, size: 18),
                    label: const Text('Đăng xuất thiết bị khác'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.scheme.error,
              side: BorderSide(color: context.scheme.error),
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(LucideIcons.logOut, size: 18),
            label: const Text('Đăng xuất'),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Core CD Mobile 1.0.0',
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _lockAvailableProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(biometricProvider).isAvailable(),
);

/// M26 – Trạng thái hệ thống: mạng, máy chủ, phiên, phiên bản.
class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).value ?? true;
    final health = ref.watch(_healthProvider);
    final config = ref.watch(appConfigProvider);
    final user = ref.watch(currentUserProvider);

    Widget dot(bool ok) => StatusChip(
      ok
          ? (label: 'Bình thường', tone: Tone.success)
          : (label: 'Có vấn đề', tone: Tone.danger),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Trạng thái hệ thống')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_healthProvider);
          await ref.read(_healthProvider.future).catchError((_) => false);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            if (!online)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: OfflineBanner(),
              ),
            ListGroup(
              children: [
                InfoRow('Kết nối mạng', null, valueWidget: dot(online)),
                InfoRow(
                  'Máy chủ',
                  null,
                  valueWidget: health.when(
                    data: dot,
                    loading: () => const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) => dot(false),
                  ),
                ),
                const InfoRow(
                  'Phiên đăng nhập',
                  null,
                  valueWidget: StatusChip((
                    label: 'Hợp lệ',
                    tone: Tone.success,
                  )),
                ),
              ],
            ),
            const SectionHeader('Thông tin ứng dụng'),
            const SizedBox(height: 8),
            ListGroup(
              children: [
                const InfoRow('Phiên bản', '1.0.0'),
                InfoRow('Môi trường', config.envName),
                InfoRow('Vai trò', user.role.label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Máy chủ có phản hồi `/health` không (không cần xác thực).
final _healthProvider = FutureProvider.autoDispose<bool>((ref) async {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      validateStatus: (_) => true,
    ),
  );
  try {
    final res = await dio.get<dynamic>('/health');
    return res.statusCode == 200;
  } on DioException {
    return false;
  }
});

/// Role dùng cho gợi ý quyền ở bản sau.
bool canWrite(AuthUser u) => u.role.atLeast(Role.operator);
