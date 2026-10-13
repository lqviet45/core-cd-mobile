import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/ui/paged_list.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/labels.dart';
import '../data/certificate_dto.dart';
import 'certificate_actions.dart';
import 'certificate_providers.dart';

/// Tỷ lệ thời hạn đã trôi qua của CCTG (0–1) và có đang sắp đáo hạn không.
({double elapsed, bool warn}) termProgress(Certificate c, DateTime today) {
  final total = c.maturityDate.difference(c.issueDate).inDays;
  final done = today.difference(c.issueDate).inDays;
  final elapsed = total <= 0 ? 1.0 : (done / total).clamp(0.0, 1.0);
  return (
    elapsed: elapsed,
    warn: c.status == 'NearMaturity' || c.status == 'Matured',
  );
}

DateTime _today() {
  final n = DateTime.now().toUtc();
  return DateTime.utc(n.year, n.month, n.day);
}

/// M05 – Danh sách chứng chỉ tiền gửi.
class CertificateListScreen extends ConsumerStatefulWidget {
  const CertificateListScreen({super.key});

  @override
  ConsumerState<CertificateListScreen> createState() =>
      _CertificateListScreenState();
}

class _CertificateListScreenState extends ConsumerState<CertificateListScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = ref.read(certificateQueryProvider);
      ref
          .read(certificateQueryProvider.notifier)
          .set(q.copyWith(search: v.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(certificatesProvider);
    final query = ref.watch(certificateQueryProvider);
    final notifier = ref.read(certificatesProvider.notifier);

    return Scaffold(
      body: Column(
        children: [
          const BigHeader('Chứng chỉ tiền gửi'),
          SearchField(hint: 'Số CCTG, tên, CCCD', onChanged: _onSearch),
          FilterChipsRow<String>(
            options: const [
              ('', 'Tất cả'),
              ('Active', 'Đang hoạt động'),
              ('NearMaturity', 'Sắp đáo hạn'),
              ('Matured', 'Đã đáo hạn'),
            ],
            value: query.status,
            onChanged: (v) => ref
                .read(certificateQueryProvider.notifier)
                .set(query.copyWith(status: v)),
          ),
          Expanded(
            child: PagedListView<Certificate>(
              state: state,
              onRefresh: notifier.refresh,
              onLoadMore: notifier.loadMore,
              emptyTitle: 'Không có CCTG phù hợp',
              emptyMessage: 'Thử đổi bộ lọc hoặc từ khoá tìm kiếm.',
              itemBuilder: (context, c) => CertificateCard(
                c,
                onTap: () => context.push('/certificates/${c.id}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ CCTG dùng ở danh sách (`.m-card.o`).
class CertificateCard extends StatelessWidget {
  const CertificateCard(this.c, {super.key, this.onTap});
  final Certificate c;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    final today = _today();
    final p = termProgress(c, today);
    final status = certStatusOf(c.status);
    final showProgress = !c.isRedeemed && c.status != 'Cancelled';

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
                  c.certificateNumber,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    color: s.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusChip(status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.customerName,
                      style: context.text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${c.termName} · ${formatPercent(c.annualRatePercent)}/năm',
                      style: context.text.bodySmall?.copyWith(
                        color: s.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              MoneyText(
                c.principal,
                compact: true,
                style: context.text.titleLarge,
              ),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 12),
            AppProgress(
              p.elapsed,
              warn: p.warn,
              semanticLabel: 'Đã qua ${(p.elapsed * 100).round()}% thời hạn',
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                formatDate(c.issueDate),
                style: context.text.bodySmall?.copyWith(
                  color: s.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.isRedeemed
                      ? 'Tất toán ${formatDate(c.redemptionDate)}'
                      : 'Đáo hạn ${formatDate(c.maturityDate)}${p.warn ? ' · ${formatDaysFrom(c.maturityDate, today)}' : ''}',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: p.warn ? context.tones.onWarn : s.onSurfaceVariant,
                    fontWeight: p.warn ? FontWeight.w700 : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// M06 – Chi tiết CCTG.
class CertificateDetailScreen extends ConsumerWidget {
  const CertificateDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cert = ref.watch(certificateProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết CCTG')),
      bottomNavigationBar: cert.value == null
          ? null
          : CertificateActionBar(cert.value!),
      body: cert.when(
        loading: () => const ListSkeleton(rows: 3),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(certificateProvider(id)),
        ),
        data: (c) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(certificateProvider(id))
              ..invalidate(interestScheduleProvider(id));
            await ref.read(certificateProvider(id).future).catchError((_) => c);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _CertificateHero(c),
              const SizedBox(height: 12),
              ListGroup(
                children: [
                  InfoRow(
                    'Lãi suất',
                    '${formatPercent(c.annualRatePercent)}/năm',
                  ),
                  InfoRow(
                    'Kỳ hạn',
                    '${c.termName} · ${paymentMethodLabel(c.paymentMethod).toLowerCase()}',
                  ),
                  InfoRow(
                    'Lãi dự kiến cả kỳ',
                    formatMoney(c.estimatedInterest),
                  ),
                  InfoRow('Phong tỏa', formatMoney(c.holdAmount)),
                  InfoRow('Đợt phát hành', c.lotCode, mono: true),
                  InfoRow('CCCD / MST', c.customerIdentityNumber, mono: true),
                ],
              ),
              if (c.isRedeemed) ...[
                const SectionHeader('Kết quả tất toán'),
                const SizedBox(height: 8),
                ListGroup(
                  children: [
                    InfoRow('Ngày tất toán', formatDate(c.redemptionDate)),
                    InfoRow(
                      'Hình thức',
                      c.status == 'RedeemedEarly' ? 'Trước hạn' : 'Đúng hạn',
                    ),
                    InfoRow('Tổng lãi', formatMoney(c.totalInterestPaid)),
                    if (c.status == 'RedeemedEarly')
                      InfoRow(
                        'Lãi bị mất do tất toán sớm',
                        formatMoney(c.penaltyAmount),
                      ),
                    if ((c.earlyRedemptionFee ?? Decimal.zero) > Decimal.zero)
                      InfoRow(
                        'Phí tất toán sớm',
                        formatMoney(c.earlyRedemptionFee),
                      ),
                    InfoRow('Thực nhận', formatMoney(c.netAmountAtRedemption)),
                  ],
                ),
              ],
              if (c.paymentMethod != 'AtMaturity') ...[
                const SectionHeader('Lịch chi lãi'),
                const SizedBox(height: 8),
                _InterestSchedule(id),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CertificateHero extends StatelessWidget {
  const _CertificateHero(this.c);
  final Certificate c;

  @override
  Widget build(BuildContext context) {
    final on = context.scheme.onPrimaryContainer;
    final today = _today();
    final p = termProgress(c, today);
    return AppCard(
      kind: CardKind.primaryContainer,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.certificateNumber,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    color: on,
                  ),
                ),
              ),
              StatusChip(certStatusOf(c.status)),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Mệnh giá ${formatMoney(c.principal)}',
            child: ExcludeSemantics(
              child: MoneyText(
                c.principal,
                style: context.text.displayMedium?.copyWith(
                  color: on,
                  fontSize: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            c.customerName,
            style: context.text.bodyMedium?.copyWith(color: on),
          ),
          if (c.isOnHold) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(LucideIcons.lock, size: 14, color: on),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Đang phong tỏa ${formatMoney(c.holdAmount)}',
                    style: context.text.bodySmall?.copyWith(
                      color: on,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!c.isRedeemed && c.status != 'Cancelled') ...[
            const SizedBox(height: 16),
            AppProgress(
              p.elapsed,
              warn: p.warn,
              semanticLabel: 'Đã qua ${(p.elapsed * 100).round()}% thời hạn',
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                formatDate(c.issueDate),
                style: context.text.bodySmall?.copyWith(color: on),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${formatDate(c.maturityDate)}${c.isRedeemed ? '' : ' · ${formatDaysFrom(c.maturityDate, today)}'}',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(color: on),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InterestSchedule extends ConsumerWidget {
  const _InterestSchedule(this.id);
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sch = ref.watch(interestScheduleProvider(id));
    return AppCard(
      kind: CardKind.outlined,
      child: sch.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          'Không tải được lịch chi lãi.',
          style: TextStyle(color: context.scheme.error),
        ),
        data: (s) {
          final tones = context.tones;
          final scheme = context.scheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < s.periods.length; i++)
                _TimelineItem(
                  last: i == s.periods.length - 1,
                  dotColor: switch (s.periods[i].status) {
                    'Paid' => tones.okContainer,
                    'Overdue' => tones.errorContainer,
                    'Today' => scheme.primaryContainer,
                    _ => scheme.surfaceContainerHighest,
                  },
                  dotIcon: s.periods[i].status == 'Paid'
                      ? LucideIcons.check
                      : LucideIcons.coins,
                  dotFg: switch (s.periods[i].status) {
                    'Paid' => tones.onOk,
                    'Overdue' => tones.onError,
                    'Today' => scheme.onPrimaryContainer,
                    _ => scheme.onSurfaceVariant,
                  },
                  child: _PeriodText(s.periods[i]),
                ),
              const SizedBox(height: 4),
              Text(
                'Tổng lãi hợp đồng ${formatMoney(s.contractInterest)} · đã chi ${formatMoney(s.paidTotal)}',
                style: context.text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PeriodText extends StatelessWidget {
  const _PeriodText(this.p);
  final InterestPeriod p;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    final tone = interestPeriodTone(p.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MoneyText(p.amount, style: context.text.titleSmall),
            const SizedBox(width: 8),
            StatusChip((
              label: interestPeriodStatusLabel(p.status),
              tone: tone,
            )),
          ],
        ),
        Text(
          'Kỳ ${p.index}/${p.total} · ${formatDate(p.start)} → ${formatDate(p.end)}',
          style: context.text.bodySmall?.copyWith(color: s.onSurfaceVariant),
        ),
        if (p.paidDate != null)
          Text(
            'Chi ngày ${formatDate(p.paidDate)}',
            style: context.text.bodySmall?.copyWith(color: s.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// Một mốc trong timeline dọc (`.m-tl`).
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.child,
    required this.dotColor,
    required this.dotFg,
    required this.dotIcon,
    required this.last,
  });
  final Widget child;
  final Color dotColor;
  final Color dotFg;
  final IconData dotIcon;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(dotIcon, size: 14, color: dotFg),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: context.scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 20),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
