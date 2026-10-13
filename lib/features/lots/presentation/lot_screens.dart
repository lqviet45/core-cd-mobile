import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/money/money_gate.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/labels.dart';
import '../data/lot_dto.dart';

final lotStatusFilterProvider = NotifierProvider<_StringNotifier, String>(
  _StringNotifier.new,
);

class _StringNotifier extends Notifier<String> {
  @override
  String build() => 'Open';

  // ignore: use_setters_to_change_properties
  void set(String v) => state = v;
}

final lotsProvider = FutureProvider.autoDispose<List<Lot>>((ref) {
  final status = ref.watch(lotStatusFilterProvider);
  return ref.watch(lotRepositoryProvider).list(status: status);
});

final lotSummaryProvider = FutureProvider.autoDispose<LotSummary>(
  (ref) => ref.watch(lotRepositoryProvider).summary(),
);
final lotProvider = FutureProvider.autoDispose.family<Lot, String>(
  (ref, id) => ref.watch(lotRepositoryProvider).get(id),
);
final lotStatsProvider = FutureProvider.autoDispose.family<LotStats, String>(
  (ref, id) => ref.watch(lotRepositoryProvider).stats(id),
);

/// Số tiền rút gọn "31,6 / 50 tỷ".
String _ratio(Decimal a, Decimal b) {
  final unit = b.abs() >= Decimal.fromInt(1000000000)
      ? (Decimal.fromInt(1000000000), 'tỷ')
      : (Decimal.fromInt(1000000), 'tr');
  String f(Decimal v) => formatPercent(
    (v / unit.$1).toDecimal(scaleOnInfinitePrecision: 2),
    maxDigits: 1,
  ).replaceAll('%', '');
  return '${f(a)} / ${f(b)} ${unit.$2}';
}

/// M19 – Đợt phát hành (Lô CD).
class LotListScreen extends ConsumerWidget {
  const LotListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(lotStatusFilterProvider);
    final lots = ref.watch(lotsProvider);
    final summary = ref.watch(lotSummaryProvider);

    Future<void> refresh() async {
      ref
        ..invalidate(lotsProvider)
        ..invalidate(lotSummaryProvider);
      try {
        await ref.read(lotsProvider.future);
      } on Object {
        // hiển thị qua trạng thái lỗi
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Đợt phát hành')),
      body: Column(
        children: [
          FilterChipsRow<String>(
            options: const [
              ('Open', 'Đang mở'),
              ('SoldOut', 'Hết hạn mức'),
              ('Closed', 'Đã đóng'),
            ],
            value: status,
            onChanged: (v) => ref.read(lotStatusFilterProvider.notifier).set(v),
          ),
          Expanded(
            child: lots.when(
              loading: () => const ListSkeleton(),
              error: (e, _) => ErrorState(error: e, onRetry: refresh),
              data: (items) => RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    if (summary.value case final s?) ...[
                      Row(
                        children: [
                          Expanded(
                            child: AppCard(
                              kind: CardKind.primaryContainer,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Đã phát hành',
                                    style: context.text.bodySmall,
                                  ),
                                  Text(
                                    '${formatCompact(s.openIssuedFaceValue)} ₫',
                                    style: context.text.titleLarge,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Còn lại',
                                    style: context.text.bodySmall?.copyWith(
                                      color: context.scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '${formatCompact(s.openRemainingFaceValue)} ₫',
                                    style: context.text.titleLarge,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (items.isEmpty)
                      const SizedBox(
                        height: 320,
                        child: EmptyState(
                          title: 'Không có đợt phát hành',
                          message: 'Thử chọn trạng thái khác.',
                        ),
                      )
                    else
                      for (final l in items) ...[
                        LotCard(
                          l,
                          onTap: () => context.push('/more/lots/${l.id}'),
                        ),
                        const SizedBox(height: 12),
                      ],
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

class LotCard extends StatelessWidget {
  const LotCard(this.l, {super.key, this.onTap});
  final Lot l;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    final pct = l.issuedPercent;
    final st = l.isNearlySoldOut
        ? (label: 'Sắp hết', tone: Tone.warning)
        : lotStatusOf(l.status);
    return AppCard(
      kind: CardKind.outlined,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.lotCode,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    color: s.onSurfaceVariant,
                  ),
                ),
              ),
              StatusChip(st),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${l.termName} · ${formatPercent(l.annualRatePct)}/năm',
            style: context.text.titleMedium,
          ),
          Text(
            '${paymentMethodLabel(l.paymentMethod)} · đáo hạn ${formatDate(l.maturityDate)}',
            style: context.text.bodySmall?.copyWith(color: s.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          AppProgress(
            pct / 100,
            warn: l.isNearlySoldOut,
            semanticLabel: 'Đã phát hành ${pct.round()}%',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${_ratio(l.issuedFaceValue, l.totalFaceValue)} · ${pct.round()}%',
                style: context.text.bodySmall?.copyWith(
                  color: s.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                'Còn ${formatCompact(l.remainingFaceValue)} ₫',
                style: context.text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// M20 – Chi tiết đợt phát hành.
class LotDetailScreen extends ConsumerWidget {
  const LotDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lot = ref.watch(lotProvider(id));
    final stats = ref.watch(lotStatsProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          lot.value?.lotCode ?? 'Đợt phát hành',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 18),
        ),
      ),
      body: lot.when(
        loading: () => const ListSkeleton(rows: 3),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(lotProvider(id)),
        ),
        data: (l) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(lotProvider(id))
              ..invalidate(lotStatsProvider(id));
            await ref.read(lotProvider(id).future).catchError((_) => l);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              AppCard(
                kind: CardKind.primary,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l.termName} · ${formatPercent(l.annualRatePct)}/năm',
                            style: context.text.titleMedium?.copyWith(
                              color: context.scheme.onPrimary,
                            ),
                          ),
                        ),
                        StatusChip(
                          l.isNearlySoldOut
                              ? (label: 'Sắp hết', tone: Tone.warning)
                              : lotStatusOf(l.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatCompact(l.remainingFaceValue)} ₫',
                      style: context.text.displayMedium?.copyWith(
                        color: context.scheme.onPrimary,
                      ),
                    ),
                    Text(
                      'hạn mức còn lại / ${formatCompact(l.totalFaceValue)} ₫',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppProgress(
                      l.issuedPercent / 100,
                      semanticLabel: 'Đã phát hành ${l.issuedPercent.round()}%',
                      fill: context.scheme.onPrimary,
                      track: context.scheme.onPrimary.withValues(alpha: .25),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Đã bán ${formatPercent(Decimal.parse(l.issuedPercent.toStringAsFixed(1)), maxDigits: 1)}',
                          style: context.text.bodySmall?.copyWith(
                            color: context.scheme.onPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${formatInt(l.certificateCount)} CCTG',
                          style: context.text.bodySmall?.copyWith(
                            color: context.scheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (ref.watch(canWriteProvider) &&
                  l.status == 'Open' &&
                  l.remainingFaceValue > Decimal.zero) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/trade/buy?lotId=${l.id}'),
                    icon: const Icon(LucideIcons.download, size: 18),
                    label: const Text('Mua CCTG từ đợt này'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ListGroup(
                children: [
                  InfoRow('Trả lãi', paymentMethodLabel(l.paymentMethod)),
                  InfoRow('Mua tối thiểu', formatMoney(l.minPurchaseAmount)),
                  InfoRow('Mở bán', formatDate(l.issueDate)),
                  InfoRow('Đáo hạn', formatDate(l.maturityDate)),
                ],
              ),
              const SectionHeader('Phát hành theo ngày'),
              const SizedBox(height: 8),
              AppCard(
                kind: CardKind.outlined,
                child: stats.when(
                  loading: () => const SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text(
                    'Không tải được thống kê.',
                    style: TextStyle(color: context.scheme.error),
                  ),
                  data: (s) => s.issuedByDay.isEmpty
                      ? const Text('Chưa có phát hành.')
                      : _IssuedChart(s.issuedByDay),
                ),
              ),
              if (stats.value case final s? when s.buyerMix.isNotEmpty) ...[
                const SectionHeader('Cơ cấu người mua'),
                const SizedBox(height: 8),
                ListGroup(
                  children: [
                    for (final b in s.buyerMix)
                      InfoRow(
                        customerTypeLabel(b.customerType),
                        '${formatCompact(b.principal)} ₫ · ${formatPercent(b.percent, maxDigits: 0)}',
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

class _IssuedChart extends StatelessWidget {
  const _IssuedChart(this.days);
  final List<DailyIssued> days;

  @override
  Widget build(BuildContext context) {
    final color = chartColors(Theme.of(context).brightness).first;
    final data = days.length > 14 ? days.sublist(days.length - 14) : days;
    final maxY = data
        .map((d) => d.amount.toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);
    return Semantics(
      label: 'Biểu đồ phát hành theo ngày, ${data.length} ngày gần nhất',
      child: SizedBox(
        height: 160,
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
                  reservedSize: 24,
                  getTitlesWidget: (v, meta) {
                    final i = v.toInt();
                    if (i < 0 || i >= data.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${data[i].date.day}/${data[i].date.month}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < data.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i].amount.toDouble(),
                      color: color,
                      width: 14,
                      borderRadius: BorderRadius.circular(3),
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
