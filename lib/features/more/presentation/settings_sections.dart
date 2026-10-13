import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/providers.dart';
import '../../../core/network/api_call.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/settings/app_prefs.dart';
import '../../../core/ui/snack.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';

/// Loại thông báo và nhãn hiển thị (khớp `NotificationType` của backend).
const notificationTypeLabels = <String, String>{
  'NearMaturity': 'Nhắc CCTG sắp đáo hạn',
  'TransactionFailed': 'Cảnh báo giao dịch thất bại',
  'LotNearlySoldOut': 'Đợt phát hành sắp hết hạn mức',
  'JobSummary': 'Tóm tắt tác vụ định kỳ',
};

/// Các loại thông báo đang bị tắt (phía máy chủ, theo từng người dùng).
class MutedTypesNotifier extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() => apiCall(() async {
    final res = await ref
        .watch(dioProvider)
        .get<List<dynamic>>('/api/notifications/preferences');
    return {
      for (final e in res.data!)
        if ((e as Map<String, dynamic>)['muted'] == true) e['type'] as String,
    };
  });

  /// Cập nhật lạc quan; lỗi thì khôi phục và ném lại để UI báo.
  Future<void> setMuted(String type, {required bool muted}) async {
    final before = state.value ?? <String>{};
    final next = {...before};
    if (muted) {
      next.add(type);
    } else {
      next.remove(type);
    }
    state = AsyncData(next);
    try {
      await apiCall(
        () => ref
            .read(dioProvider)
            .put<void>(
              '/api/notifications/preferences',
              data: {'mutedTypes': next.toList()},
            ),
      );
    } on ApiException {
      state = AsyncData(before);
      rethrow;
    }
  }
}

final mutedTypesProvider =
    AsyncNotifierProvider<MutedTypesNotifier, Set<String>>(
      MutedTypesNotifier.new,
    );

Future<T?> _pick<T>(
  BuildContext context, {
  required String title,
  required T current,
  required List<(T, String)> options,
}) => showModalBottomSheet<T>(
  context: context,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    child: RadioGroup<T>(
      groupValue: current,
      onChanged: (v) => Navigator.of(sheet).pop(v),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: sheet.text.titleLarge),
            ),
          ),
          for (final (v, label) in options)
            RadioListTile<T>(value: v, title: Text(label)),
        ],
      ),
    ),
  ),
);

String _themeLabel(ThemeMode m) => switch (m) {
  ThemeMode.system => 'Theo hệ thống',
  ThemeMode.light => 'Sáng',
  ThemeMode.dark => 'Tối',
};

String lockAfterLabel(Duration d) => '${d.inMinutes} phút khi ở nền';

/// Khoá nhanh, tự khoá, đổi mật khẩu.
class SecuritySettings extends ConsumerWidget {
  const SecuritySettings({super.key, required this.lockable});

  /// Thiết bị có khoá màn hình/sinh trắc để dùng không.
  final bool lockable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPrefsProvider);
    final notifier = ref.read(appPrefsProvider.notifier);

    Future<void> toggleLock(bool v) async {
      if (!v) {
        // Tắt khoá nhanh là hạ mức bảo vệ → phải xác thực trước.
        final ok = await ref
            .read(biometricProvider)
            .authenticate('Xác thực để tắt khoá nhanh');
        if (!ok) return;
      }
      await notifier.setLockEnabled(v);
    }

    return ListGroup(
      children: [
        ListRow(
          title: 'Khoá nhanh',
          subtitle: lockable
              ? 'Mở app bằng sinh trắc / mã thiết bị'
              : 'Thiết bị chưa đặt khoá màn hình',
          trailing: Switch(
            value: prefs.lockEnabled && lockable,
            onChanged: lockable ? toggleLock : null,
          ),
        ),
        ListRow(
          title: 'Tự khoá sau',
          subtitle: lockAfterLabel(prefs.lockAfter),
          chevron: prefs.lockEnabled,
          onTap: !prefs.lockEnabled
              ? null
              : () async {
                  final v = await _pick<Duration>(
                    context,
                    title: 'Tự khoá sau',
                    current: prefs.lockAfter,
                    options: [
                      for (final d in AppPrefs.lockChoices)
                        (d, lockAfterLabel(d)),
                    ],
                  );
                  if (v != null) await notifier.setLockAfter(v);
                },
        ),
        ListRow(
          title: 'Đổi mật khẩu',
          subtitle: 'Các thiết bị khác sẽ phải đăng nhập lại',
          chevron: true,
          onTap: () => context.push('/more/account/password'),
        ),
      ],
    );
  }
}

/// Giao diện sáng/tối và ẩn số tiền.
class AppearanceSettings extends ConsumerWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPrefsProvider);
    final notifier = ref.read(appPrefsProvider.notifier);
    return ListGroup(
      children: [
        ListRow(
          title: 'Giao diện',
          subtitle: _themeLabel(prefs.themeMode),
          chevron: true,
          onTap: () async {
            final v = await _pick<ThemeMode>(
              context,
              title: 'Giao diện',
              current: prefs.themeMode,
              options: [for (final m in ThemeMode.values) (m, _themeLabel(m))],
            );
            if (v != null) await notifier.setThemeMode(v);
          },
        ),
        ListRow(
          title: 'Ẩn số tiền trên màn hình chính',
          trailing: Switch(
            value: prefs.hideAmounts,
            onChanged: notifier.setHideAmounts,
          ),
        ),
      ],
    );
  }
}

/// Bật/tắt từng loại thông báo (lưu ở máy chủ nên áp dụng cả cho web và push).
class NotificationSettings extends ConsumerWidget {
  const NotificationSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = ref.watch(mutedTypesProvider);
    return muted.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(mutedTypesProvider),
      ),
      data: (set) => ListGroup(
        children: [
          for (final e in notificationTypeLabels.entries)
            ListRow(
              title: e.value,
              trailing: Switch(
                value: !set.contains(e.key),
                onChanged: (on) async {
                  try {
                    await ref
                        .read(mutedTypesProvider.notifier)
                        .setMuted(e.key, muted: !on);
                  } on ApiException catch (err) {
                    if (context.mounted) {
                      showSnack(context, err.message, error: true);
                    }
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Dải nhỏ giữa các nhóm cài đặt.
Widget settingsHeader(String title) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [SectionHeader(title), const SizedBox(height: 8)],
);

const settingsIcon = LucideIcons.settings;
