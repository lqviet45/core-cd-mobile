import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/models/paged.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/ui/paged_list.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../dashboard/presentation/providers.dart';
import '../data/notification_repository.dart';

final notificationUnreadOnlyProvider = NotifierProvider<_UnreadFilter, bool>(
  _UnreadFilter.new,
);

class _UnreadFilter extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void set(bool v) => state = v;
}

class NotificationsNotifier extends PagedNotifier<AppNotification> {
  @override
  PagedState<AppNotification> build() {
    ref.watch(notificationUnreadOnlyProvider);
    return super.build();
  }

  @override
  Future<Paged<AppNotification>> fetch(int page) => ref
      .read(notificationRepositoryProvider)
      .list(page: page, unreadOnly: ref.read(notificationUnreadOnlyProvider));
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, PagedState<AppNotification>>(
      NotificationsNotifier.new,
    );

({IconData icon, LeadKind kind}) _style(AppNotification n) => switch (n.type) {
  'NearMaturity' => (icon: LucideIcons.calendar, kind: LeadKind.warn),
  'TransactionFailed' => (
    icon: LucideIcons.triangleAlert,
    kind: LeadKind.error,
  ),
  'LotNearlySoldOut' => (icon: LucideIcons.layers, kind: LeadKind.primary),
  'JobSummary' => (
    icon: LucideIcons.timer,
    kind: n.severity == 'Critical' ? LeadKind.error : LeadKind.ok,
  ),
  _ => (icon: LucideIcons.bell, kind: LeadKind.primary),
};

/// Đường dẫn web của backend → màn hình mobile tương ứng (null = không có trang đích).
String? _routeFor(String? link) {
  if (link == null) return null;
  final lot = RegExp(r'^/lots/([0-9a-f-]{36})$').firstMatch(link);
  if (lot != null) return '/more/lots/${lot.group(1)}';
  if (link == '/settlement') return '/more/maturities';
  if (link == '/transactions' || link.startsWith('/transactions/')) {
    return '/transactions';
  }
  return null;
}

String _timeAgo(DateTime d) {
  final l = d.toLocal();
  final now = DateTime.now();
  final sameDay =
      l.year == now.year && l.month == now.month && l.day == now.day;
  String two(int v) => v.toString().padLeft(2, '0');
  return sameDay
      ? '${two(l.hour)}:${two(l.minute)}'
      : '${two(l.day)}/${two(l.month)}';
}

/// M04 – Thông báo.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final unreadOnly = ref.watch(notificationUnreadOnlyProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    Future<void> markAll() async {
      await ref.read(notificationRepositoryProvider).markRead();
      ref.invalidate(unreadCountProvider);
      await notifier.refresh();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconBtn(
            icon: LucideIcons.check,
            label: 'Đánh dấu đã đọc tất cả',
            onPressed: unread == 0 ? null : markAll,
          ),
        ],
      ),
      body: Column(
        children: [
          FilterChipsRow<bool>(
            options: [
              (false, 'Tất cả'),
              (true, 'Chưa đọc${unread > 0 ? ' · $unread' : ''}'),
            ],
            value: unreadOnly,
            onChanged: (v) =>
                ref.read(notificationUnreadOnlyProvider.notifier).set(v),
          ),
          Expanded(
            child: PagedListView<AppNotification>(
              state: state,
              onRefresh: notifier.refresh,
              onLoadMore: notifier.loadMore,
              emptyTitle: unreadOnly
                  ? 'Không còn thông báo chưa đọc'
                  : 'Chưa có thông báo',
              separatorHeight: 0,
              itemBuilder: (context, n) {
                final st = _style(n);
                final s = context.scheme;
                return Container(
                  decoration: BoxDecoration(
                    color: n.isRead
                        ? s.surfaceContainerLow
                        : s.primaryContainer.withValues(alpha: .35),
                    border: Border(bottom: BorderSide(color: s.outlineVariant)),
                  ),
                  child: Semantics(
                    label: '${n.isRead ? '' : 'Chưa đọc: '}${n.title}',
                    child: ListRow(
                      lead: Lead(icon: st.icon, kind: st.kind),
                      title: n.title,
                      subtitle: n.body,
                      trailing: Text(
                        _timeAgo(n.createdAt),
                        style: context.text.bodySmall?.copyWith(
                          color: s.onSurfaceVariant,
                        ),
                      ),
                      onTap: () async {
                        final route = _routeFor(n.linkUrl);
                        if (!n.isRead) {
                          await ref
                              .read(notificationRepositoryProvider)
                              .markRead([n.id]);
                          ref.invalidate(unreadCountProvider);
                          await notifier.refresh();
                        }
                        if (route != null && context.mounted) {
                          await context.push(route);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
