import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/format.dart';
import '../data/customer_app_dto.dart';
import 'customer_common.dart';
import 'customer_documents.dart';
import 'customer_providers.dart';
import 'kh_format.dart';
import 'kh_theme.dart';
import 'kh_widgets.dart';

/// K03 – CCTG của tôi: lọc Tất cả / Đang gửi / Sắp đáo hạn / Đã tất toán.
class CustomerCertificatesScreen extends ConsumerStatefulWidget {
  const CustomerCertificatesScreen({super.key});

  @override
  ConsumerState<CustomerCertificatesScreen> createState() => _ListState();
}

class _ListState extends ConsumerState<CustomerCertificatesScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        unawaited(ref.read(custCertificatesProvider.notifier).loadMore());
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(custCertScopeProvider);
    final state = ref.watch(custCertificatesProvider);
    final notifier = ref.read(custCertificatesProvider.notifier);
    final summary = ref.watch(custSummaryProvider).value;

    Widget body;
    if (state.loading) {
      body = const KhSkeleton();
    } else if (state.error != null) {
      body = KhError(error: state.error!, onRetry: notifier.refresh);
    } else if (state.isEmpty) {
      body = RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          children: [
            SizedBox(
              height: 360,
              child: KhEmpty(
                icon: LucideIcons.fileText,
                title: scope == 'Closed'
                    ? 'Chưa có CCTG đã tất toán'
                    : 'Không có CCTG nào ở mục này',
                message: 'Khi bạn có chứng chỉ tiền gửi, thông tin sẽ hiển thị tại đây.',
              ),
            ),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount:
              state.items.length +
              ((state.loadingMore || state.loadMoreError != null) ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i < state.items.length) return KhCertCard(state.items[i]);
            return state.loadMoreError != null
                ? Center(
                    child: TextButton(
                      onPressed: notifier.loadMore,
                      child: const Text('Không tải thêm được – thử lại'),
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
          },
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          const KhTopBar(height: 56),
          KhLargeTitle(
            'CCTG của tôi',
            subtitle: summary == null
                ? null
                : '${summary.holdingCount} đang gửi · ${summary.closedCount} đã tất toán',
          ),
          KhChips<String>(
            options: const [
              ('All', 'Tất cả'),
              ('Active', 'Đang gửi'),
              ('NearMaturity', 'Sắp đáo hạn'),
              ('Closed', 'Đã tất toán'),
            ],
            value: scope,
            onChanged: (v) => ref.read(custCertScopeProvider.notifier).set(v),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// K04 – Chi tiết CCTG: thẻ tổng, thông tin, lịch nhận lãi, nút Hợp đồng.
class CustomerCertificateDetailScreen extends ConsumerWidget {
  const CustomerCertificateDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cert = ref.watch(custCertificateProvider(id));
    return Scaffold(
      body: Column(
        children: [
          KhTopBar(title: 'Chi tiết CCTG', onBack: () => context.pop()),
          Expanded(
            child: cert.when(
              loading: () => const KhSkeleton(rows: 2),
              error: (e, _) => KhError(
                error: e,
                onRetry: () => ref.invalidate(custCertificateProvider(id)),
              ),
              data: (c) => RefreshIndicator(
                onRefresh: () async {
                  ref
                    ..invalidate(custCertificateProvider(id))
                    ..invalidate(custScheduleProvider(id));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    _SummaryCard(c),
                    const SizedBox(height: 18),
                    _InfoList(c),
                    const SizedBox(height: 18),
                    _Schedule(id: id, paymentMethod: c.paymentMethod),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'Cần hỗ trợ? Liên hệ chuyên viên của bạn.',
                        style: KhType.s.copyWith(
                          color: context.kh.pri,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.kh.bg,
              border: Border(top: BorderSide(color: context.kh.line)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: SafeArea(
              top: false,
              child: KhButton(
                label: 'Hợp đồng',
                icon: LucideIcons.download,
                kind: KhButtonKind.outlined,
                onPressed: () => openCertificateDocuments(context, ref, id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.c);
  final CustCertificate c;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    final (label, kind) = khCertPill(c.status);
    final now = DateTime.now();
    final soon = khIsSoon(c.status);
    return KhCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.certificateNumber,
                  style: KhType.code.copyWith(
                    color: k.ink3,
                    fontFeatures: KhType.nums,
                  ),
                ),
              ),
              KhPill(label, kind: kind),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatMoney(c.principal),
            style: KhType.d1.copyWith(color: k.ink, fontFeatures: KhType.nums),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${khTerm(c.termName)} · ${khPercent(c.annualRatePercent)}/năm',
            style: KhType.s.copyWith(color: k.ink2),
          ),
          if (c.isHolding) ...[
            const SizedBox(height: 18),
            KhBar(khProgress(c.issueDate, c.maturityDate, now), soon: soon),
            KhMeta(
              left: formatDate(c.issueDate),
              center: khCountdown(khDaysUntil(c.maturityDate, now)),
              right: formatDate(c.maturityDate),
              soon: soon,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoList extends StatelessWidget {
  const _InfoList(this.c);
  final CustCertificate c;

  @override
  Widget build(BuildContext context) {
    final closed = !c.isHolding;
    return KhList(
      children: [
        KhInfoRow('Nhận lãi', khMethodShort(c.paymentMethod)),
        KhInfoRow('Lãi dự kiến cả kỳ', formatMoney(c.estimatedInterest)),
        if (!closed)
          KhInfoRow(
            'Tổng nhận khi đáo hạn',
            formatMoney(c.principal + c.estimatedInterest),
          ),
        if (c.totalInterestPaid > Decimal.zero)
          KhInfoRow('Lãi đã nhận', formatMoney(c.totalInterestPaid)),
        if (closed && c.redemptionDate != null)
          KhInfoRow('Ngày tất toán', formatDate(c.redemptionDate)),
        if (closed && c.netAmountAtRedemption != null)
          KhInfoRow('Số tiền đã nhận', formatMoney(c.netAmountAtRedemption)),
      ],
    );
  }
}

class _Schedule extends ConsumerStatefulWidget {
  const _Schedule({required this.id, required this.paymentMethod});
  final String id;
  final String paymentMethod;

  @override
  ConsumerState<_Schedule> createState() => _ScheduleState();
}

class _ScheduleState extends ConsumerState<_Schedule> {
  static const _collapsed = 3;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final sched = ref.watch(custScheduleProvider(widget.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sched.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => KhError(
            error: e,
            onRetry: () => ref.invalidate(custScheduleProvider(widget.id)),
          ),
          data: (s) {
            if (s.periods.isEmpty) {
              return KhNote(
                'Lãi trả một lần khi đáo hạn: ${formatMoney(s.contractInterest)}.',
                icon: LucideIcons.calendarCheck,
              );
            }
            final shown = _all
                ? s.periods
                : s.periods.take(_collapsed).toList();
            final next = s.periods.indexWhere((p) => p.status != 'Paid');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KhSection(
                  'Lịch nhận lãi',
                  actionLabel: s.periods.length > _collapsed
                      ? (_all ? 'Thu gọn' : 'Xem ${s.periods.length} kỳ')
                      : null,
                  onAction: () => setState(() => _all = !_all),
                ),
                const SizedBox(height: 12),
                KhCard(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      for (var i = 0; i < shown.length; i++)
                        _TimelineItem(
                          p: shown[i],
                          isNext:
                              shown[i].index ==
                              (next < 0 ? -1 : s.periods[next].index),
                          last: i == shown.length - 1,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.p,
    required this.isNext,
    required this.last,
  });
  final CustInterestPeriod p;
  final bool isNext;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    final paid = p.status == 'Paid';
    String d(DateTime x) =>
        '${khDay(x)}/${x.toUtc().month.toString().padLeft(2, '0')}';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 7),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isNext || paid ? (paid ? k.ok : k.pri) : k.sf,
                    border: Border.all(
                      color: isNext ? k.pri : (paid ? k.ok : k.line2),
                      width: 2,
                    ),
                  ),
                ),
                if (!last) Expanded(child: Container(width: 2, color: k.line)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kỳ ${p.index}/${p.total}',
                          style: KhType.b.copyWith(
                            color: k.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${d(p.start)} → ${d(p.end)}\n${paid ? 'Đã nhận ${formatDate(p.paidDate)}' : 'Nhận ngày ${d(p.end)}'}',
                          style: KhType.c.copyWith(color: paid ? k.ok : k.ink3),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${formatMoney(p.amount)}',
                    style: KhType.b.copyWith(
                      color: isNext ? k.ok : k.ink,
                      fontWeight: FontWeight.w600,
                      fontFeatures: KhType.nums,
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
}
