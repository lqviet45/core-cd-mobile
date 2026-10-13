import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/providers.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/text.dart';
import '../../reports/data/report_dto.dart';
import '../data/dashboard_dto.dart';
import 'providers.dart';

/// M03 – Tổng quan.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final dash = ref.watch(dashboardProvider);
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    Future<void> refresh() async {
      ref
        ..invalidate(dashboardProvider)
        ..invalidate(upcomingProvider)
        ..invalidate(unreadCountProvider);
      try {
        await ref.read(dashboardProvider.future);
      } on Object {
        // Lỗi đã được hiển thị bởi trạng thái error của provider.
      }
    }

    final date = dash.value?.asOfDate;
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (date != null)
                          Text(
                            weekdayDateOf(date),
                            style: context.text.bodySmall?.copyWith(
                              color: context.scheme.onSurfaceVariant,
                            ),
                          ),
                        Text(
                          'Xin chào, ${givenNameOf(user.fullName)}',
                          style: context.text.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconBtn(
                    icon: LucideIcons.bell,
                    label: 'Thông báo',
                    badge: unread,
                    onPressed: () => context.push('/notifications'),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          Expanded(
            child: dash.when(
              loading: () => const ListSkeleton(rows: 3),
              error: (e, _) => ErrorState(error: e, onRetry: refresh),
              data: (d) => RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _OutstandingCard(d),
                    const SizedBox(height: 12),
                    _AlertCards(d),
                    const SizedBox(height: 20),
                    const _Shortcuts(),
                    const SizedBox(height: 8),
                    SectionHeader(
                      'Sắp đáo hạn',
                      actionLabel: 'Xem tất cả',
                      onAction: () => context.push('/more/maturities'),
                    ),
                    const SizedBox(height: 8),
                    _UpcomingList(asOf: d.asOfDate),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutstandingCard extends StatelessWidget {
  const _OutstandingCard(this.d);
  final Dashboard d;

  @override
  Widget build(BuildContext context) {
    final on = context.scheme.onPrimary;
    Widget stat(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: on.withValues(alpha: .85)),
          ),
          const SizedBox(height: 2),
          Text(value, style: context.text.titleMedium?.copyWith(color: on)),
        ],
      ),
    );
    return AppCard(
      kind: CardKind.primary,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dư nợ gốc',
            style: context.text.bodyMedium?.copyWith(color: on),
          ),
          const SizedBox(height: 4),
          Semantics(
            label: 'Dư nợ gốc ${formatMoney(d.outstandingPrincipal)}',
            child: ExcludeSemantics(
              child: Text(
                '${formatCompact(d.outstandingPrincipal)} ₫',
                style: context.text.displayMedium?.copyWith(color: on),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat('CCTG nắm giữ', formatInt(d.holdingCertificates)),
              stat('Khách hàng', formatInt(d.activeCustomers)),
              stat('Hạn mức còn', formatCompact(d.openLotsRemainingFaceValue)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertCards extends StatelessWidget {
  const _AlertCards(this.d);
  final Dashboard d;

  @override
  Widget build(BuildContext context) {
    final failed = d.failedTransactionsLast24h;
    Widget card({
      required CardKind kind,
      required IconData icon,
      required String title,
      required String value,
      required String sub,
    }) {
      final fg = AppCard.onColor(context, kind);
      return Expanded(
        child: AppCard(
          kind: kind,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: context.text.titleSmall?.copyWith(color: fg),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: context.text.headlineSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(sub, style: context.text.bodySmall?.copyWith(color: fg)),
            ],
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          card(
            kind: CardKind.warn,
            icon: LucideIcons.calendar,
            title: 'Đáo hạn 7 ngày',
            value: formatInt(d.maturing7DaysCount),
            sub: '${formatCompact(d.maturing7DaysPrincipal)} ₫',
          ),
          const SizedBox(width: 12),
          card(
            kind: failed > 0 ? CardKind.error : CardKind.filled,
            icon: LucideIcons.triangleAlert,
            title: 'Lỗi 24 giờ',
            value: formatInt(failed),
            sub: failed > 0 ? 'Cần kiểm tra' : 'Không có lỗi',
          ),
        ],
      ),
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, String route) => Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(Tokens.radiusCard),
          onTap: () => context.push(route),
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.scheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: context.scheme.onSecondaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        item(LucideIcons.calendar, 'Lịch đáo hạn', '/more/maturities'),
        item(LucideIcons.layers, 'Đợt phát hành', '/more/lots'),
        item(LucideIcons.chartColumn, 'Báo cáo', '/more/reports'),
        item(LucideIcons.repeat, 'Giao dịch', '/transactions'),
      ],
    );
  }
}

class _UpcomingList extends ConsumerWidget {
  const _UpcomingList({required this.asOf});
  final DateTime asOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final up = ref.watch(upcomingProvider);
    return up.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppCard(
        kind: CardKind.outlined,
        child: Text(
          'Không tải được lịch đáo hạn.',
          style: TextStyle(color: context.scheme.error),
        ),
      ),
      data: (r) {
        final rows = <(UpcomingGroup, UpcomingItem)>[
          for (final g in r.byDate)
            for (final i in g.items) (g, i),
        ].take(5).toList();
        if (rows.isEmpty) {
          return const AppCard(
            kind: CardKind.outlined,
            child: Text('Không có CCTG đáo hạn trong 30 ngày tới.'),
          );
        }
        return ListGroup(
          children: [
            for (final (g, i) in rows)
              ListRow(
                lead: Lead(
                  square: true,
                  kind: LeadKind.warn,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${g.maturityDate.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: context.tones.onWarn,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        'T${g.maturityDate.month}',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.tones.onWarn,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                title: i.customerName,
                subtitle:
                    '${formatDaysFrom(g.maturityDate, asOf)} · ${i.certificateNumber}',
                trailing: Text(
                  '${formatCompact(i.estimatedPayout)} ₫',
                  style: context.text.titleMedium,
                ),
                onTap: () => context.push('/more/maturities'),
              ),
          ],
        );
      },
    );
  }
}
