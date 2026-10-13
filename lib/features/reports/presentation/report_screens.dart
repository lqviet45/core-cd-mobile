import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/labels.dart';
import '../../dashboard/presentation/providers.dart';
import '../data/report_dto.dart';

final portfolioProvider = FutureProvider.autoDispose<PortfolioReport>(
  (ref) => ref.watch(reportRepositoryProvider).portfolio(),
);

final liquidityProvider = FutureProvider.autoDispose<LiquidityReport>((ref) {
  final now = DateTime.now().toUtc();
  final from = DateTime.utc(now.year, now.month);
  final to = DateTime.utc(
    now.year,
    now.month + 6,
    0,
  ); // hết tháng thứ 6 kể từ tháng hiện tại
  return ref.watch(reportRepositoryProvider).liquidity(from: from, to: to);
});

enum _ReportTab { portfolio, liquidity }

final _reportTabProvider = NotifierProvider<_TabNotifier, _ReportTab>(
  _TabNotifier.new,
);

class _TabNotifier extends Notifier<_ReportTab> {
  @override
  _ReportTab build() => _ReportTab.portfolio;

  // ignore: use_setters_to_change_properties
  void set(_ReportTab t) => state = t;
}

/// M22 – Báo cáo (danh mục, thanh khoản).
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_reportTabProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: Column(
        children: [
          FilterChipsRow<_ReportTab>(
            options: const [
              (_ReportTab.portfolio, 'Danh mục'),
              (_ReportTab.liquidity, 'Thanh khoản'),
            ],
            value: tab,
            onChanged: (v) => ref.read(_reportTabProvider.notifier).set(v),
          ),
          Expanded(
            child: tab == _ReportTab.portfolio
                ? const _PortfolioTab()
                : const _LiquidityTab(),
          ),
        ],
      ),
    );
  }
}

class _PortfolioTab extends ConsumerWidget {
  const _PortfolioTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(portfolioProvider);
    return r.when(
      loading: () => const ListSkeleton(rows: 3),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(portfolioProvider),
      ),
      data: (p) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(portfolioProvider);
          await ref.read(portfolioProvider.future).catchError((_) => p);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dư nợ gốc hiện tại',
                    style: context.text.bodySmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${formatCompact(p.totalOutstandingPrincipal)} ₫',
                    style: context.text.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatInt(p.totalActiveCertificates)} CCTG · lãi dự kiến ${formatCompact(p.totalEstimatedInterest)} ₫',
                    style: context.text.bodySmall?.copyWith(
                      color: context.scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (p.byTerm.isEmpty)
                    const Text('Chưa có dữ liệu.')
                  else
                    _TermDonut(p.byTerm),
                ],
              ),
            ),
            const SectionHeader('Theo hình thức trả lãi'),
            const SizedBox(height: 8),
            ListGroup(
              children: [
                for (final g in p.byPaymentMethod)
                  InfoRow(
                    g.label,
                    '${formatInt(g.count)} CCTG · ${formatCompact(g.totalPrincipal)} ₫',
                  ),
              ],
            ),
            const SectionHeader('Theo loại khách hàng'),
            const SizedBox(height: 8),
            ListGroup(
              children: [
                for (final g in p.byCustomerType)
                  InfoRow(
                    g.label,
                    '${formatInt(g.count)} CCTG · ${formatCompact(g.totalPrincipal)} ₫',
                  ),
              ],
            ),
            const SectionHeader('Top khách hàng'),
            const SizedBox(height: 8),
            if (p.top10Customers.isEmpty)
              const AppCard(
                kind: CardKind.outlined,
                child: Text('Chưa có dữ liệu.'),
              )
            else
              ListGroup(
                children: [
                  for (var i = 0; i < p.top10Customers.length; i++)
                    ListRow(
                      lead: Lead(text: '${i + 1}'),
                      title: p.top10Customers[i].customerName,
                      subtitle: '${p.top10Customers[i].certificateCount} CCTG',
                      trailing: Text(
                        '${formatCompact(p.top10Customers[i].totalPrincipal)} ₫',
                        style: context.text.titleSmall,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TermDonut extends StatelessWidget {
  const _TermDonut(this.groups);
  final List<GroupTotal> groups;

  @override
  Widget build(BuildContext context) {
    final colors = chartColors(Theme.of(context).brightness);
    final total = groups.fold<Decimal>(
      Decimal.zero,
      (a, g) => a + g.totalPrincipal,
    );
    double pct(GroupTotal g) =>
        total == Decimal.zero ? 0 : (g.totalPrincipal / total).toDouble() * 100;
    return Row(
      children: [
        Semantics(
          label: 'Biểu đồ cơ cấu dư nợ theo kỳ hạn',
          child: SizedBox(
            width: 120,
            height: 120,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 34,
                sections: [
                  for (var i = 0; i < groups.length; i++)
                    PieChartSectionData(
                      value: groups[i].totalPrincipal.toDouble(),
                      color: colors[i % colors.length],
                      radius: 22,
                      showTitle: false,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < groups.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          groups[i].label,
                          style: context.text.bodyMedium,
                        ),
                      ),
                      Text(
                        '${pct(groups[i]).round()}%',
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiquidityTab extends ConsumerWidget {
  const _LiquidityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(liquidityProvider);
    return r.when(
      loading: () => const ListSkeleton(rows: 3),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(liquidityProvider),
      ),
      data: (l) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(liquidityProvider);
          await ref.read(liquidityProvider.future).catchError((_) => l);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            AppCard(
              kind: CardKind.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tổng dòng tiền ra 6 tháng tới',
                    style: context.text.bodySmall,
                  ),
                  Text(
                    '${formatCompact(l.totalOutflow)} ₫',
                    style: context.text.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gốc ${formatCompact(l.totalPrincipalOutflow)} ₫ · lãi ${formatCompact(l.totalInterestOutflow)} ₫',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            const SectionHeader('Dòng tiền ra theo tháng'),
            const SizedBox(height: 8),
            AppCard(
              kind: CardKind.outlined,
              child: l.byPeriod.isEmpty
                  ? const Text('Chưa có dữ liệu.')
                  : _OutflowChart(l.byPeriod),
            ),
            const SizedBox(height: 12),
            ListGroup(
              children: [
                for (final p in l.byPeriod)
                  InfoRow(
                    p.periodLabel,
                    '${formatCompact(p.totalOutflow)} ₫ · ${p.maturityCount} CCTG',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutflowChart extends StatelessWidget {
  const _OutflowChart(this.periods);
  final List<LiquidityPeriod> periods;

  @override
  Widget build(BuildContext context) {
    final colors = chartColors(Theme.of(context).brightness);
    final maxY = periods
        .map((p) => p.totalOutflow.toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);
    return Semantics(
      label: 'Biểu đồ dòng tiền ra theo tháng',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            maxY: maxY == 0 ? 1 : maxY * 1.15,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= periods.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        periods[i].periodLabel,
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < periods.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: periods[i].totalOutflow.toDouble(),
                      width: 18,
                      borderRadius: BorderRadius.circular(3),
                      rodStackItems: [
                        BarChartRodStackItem(
                          0,
                          periods[i].principalOutflow.toDouble(),
                          colors[0],
                        ),
                        BarChartRodStackItem(
                          periods[i].principalOutflow.toDouble(),
                          periods[i].totalOutflow.toDouble(),
                          colors[2],
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// M21 – Lịch đáo hạn trong 30 ngày tới, nhóm theo ngày.
class MaturitiesScreen extends ConsumerWidget {
  const MaturitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(upcomingProvider);
    final asOf =
        ref.watch(dashboardProvider).value?.asOfDate ?? DateTime.now().toUtc();
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch đáo hạn')),
      body: r.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(upcomingProvider),
        ),
        data: (u) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(upcomingProvider);
            await ref.read(upcomingProvider.future).catchError((_) => u);
          },
          child: u.byDate.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    EmptyState(
                      title: 'Không có CCTG đáo hạn',
                      message: 'Trong 30 ngày tới không có CCTG nào đáo hạn.',
                      icon: LucideIcons.calendar,
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    AppCard(
                      kind: CardKind.warn,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trong ${u.daysAhead} ngày tới',
                                  style: context.text.bodySmall?.copyWith(
                                    color: context.tones.onWarn,
                                  ),
                                ),
                                Text(
                                  '${formatInt(u.totalCount)} CCTG · ${formatCompact(u.totalEstimatedPayout)} ₫',
                                  style: context.text.titleLarge?.copyWith(
                                    color: context.tones.onWarn,
                                  ),
                                ),
                                Text(
                                  'Dự kiến chi trả (gốc ${formatCompact(u.totalPrincipal)} ₫)',
                                  style: context.text.bodySmall?.copyWith(
                                    color: context.tones.onWarn,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final g in u.byDate) ...[
                      SectionHeader(
                        '${formatDate(g.maturityDate)} · ${formatDaysFrom(g.maturityDate, asOf)} · ${g.count} CCTG · ${formatCompact(g.totalEstimatedPayout)} ₫',
                      ),
                      const SizedBox(height: 8),
                      ListGroup(
                        children: [
                          for (final i in g.items)
                            ListRow(
                              lead: const Lead(
                                square: true,
                                kind: LeadKind.warn,
                                icon: LucideIcons.fileText,
                              ),
                              title: i.customerName,
                              subtitle:
                                  '${i.certificateNumber} · ${certStatusOf(i.status).label}',
                              trailing: Text(
                                '${formatCompact(i.estimatedPayout)} ₫',
                                style: context.text.titleMedium,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Dùng để mở màn báo cáo từ nơi khác.
void openReports(BuildContext context) => context.push('/more/reports');
