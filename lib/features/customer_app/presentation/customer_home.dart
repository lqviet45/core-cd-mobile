import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/utils/format.dart';
import '../../../core/utils/text.dart';
import '../data/customer_app_dto.dart';
import 'customer_common.dart';
import 'customer_providers.dart';
import 'kh_theme.dart';
import 'kh_widgets.dart';

/// K02 – Trang chủ: tổng tiền đang gửi, lãi dự kiến, tiền sẽ nhận trong 30 ngày tới, các khoản sắp tới và CCTG của tôi.
class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kh;
    final profile = ref.watch(custProfileProvider);
    final summary = ref.watch(custSummaryProvider);

    Future<void> refresh() async {
      ref
        ..invalidate(custProfileProvider)
        ..invalidate(custSummaryProvider)
        ..invalidate(custUpcomingProvider)
        ..invalidate(custHomeCertsProvider);
      try {
        await ref.read(custSummaryProvider.future);
      } on Object {
        // Lỗi đã hiển thị bởi trạng thái error của provider.
      }
    }

    final name = profile.value?.fullName;
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weekdayDateOf(todayBusinessDate()),
                        style: KhType.c.copyWith(color: k.ink3),
                      ),
                      Semantics(
                        header: true,
                        child: Text(
                          name == null
                              ? 'Xin chào'
                              : 'Xin chào, ${givenNameOf(name)}',
                          style: KhType.t1.copyWith(color: k.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: summary.when(
                loading: () => const KhSkeleton(rows: 2),
                error: (e, _) => ListView(
                  children: [
                    SizedBox(
                      height: 420,
                      child: KhError(error: e, onRetry: refresh),
                    ),
                  ],
                ),
                data: (s) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    _HeroCard(s),
                    const SizedBox(height: 20),
                    const _UpcomingSection(),
                    const SizedBox(height: 20),
                    _MyCertsSection(holding: s.holdingCount),
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

class _HeroCard extends ConsumerWidget {
  const _HeroCard(this.s);
  final CustomerSummary s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(custUpcomingProvider);
    final today = todayBusinessDate();
    final limit = today.add(const Duration(days: 30));
    final next30 = upcoming.whenData(
      (u) => u.items
          .where((i) => !i.date.isAfter(limit))
          .fold(Decimal.zero, (a, i) => a + i.amount),
    );
    const white = Color(0xFFFFFFFF);
    const soft = Color(0xC2FFFFFF);
    return Semantics(
      container: true,
      label: 'Tổng quan tiền gửi',
      child: KhHero(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tổng tiền đang gửi', style: KhType.s.copyWith(color: soft)),
            const SizedBox(height: 4),
            Text(
              formatMoney(s.totalPrincipal),
              style: KhType.d1.copyWith(
                color: white,
                fontFeatures: KhType.nums,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${s.holdingCount} chứng chỉ đang gửi',
              style: KhType.s.copyWith(color: soft),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: const Color(0x2EFFFFFF)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    'Lãi dự kiến cả kỳ',
                    '+${formatMoney(s.estimatedInterestTotal)}',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _Stat(
                    'Nhận 30 ngày tới',
                    next30.when(
                      data: formatMoney,
                      loading: () => '…',
                      error: (_, __) => '—',
                    ),
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

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: KhType.s.copyWith(color: const Color(0xC2FFFFFF))),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: KhType.t2.copyWith(
          color: Colors.white,
          fontFeatures: KhType.nums,
        ),
      ),
    ],
  );
}

class _UpcomingSection extends ConsumerWidget {
  const _UpcomingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(custUpcomingProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KhSection(
          'Sắp tới',
          actionLabel: 'Xem lịch',
          onAction: () => context.go('/calendar'),
        ),
        const SizedBox(height: 12),
        upcoming.when(
          loading: () => Skeletonizer(
            child: KhList(
              children: [
                for (var i = 0; i < 2; i++)
                  const KhRow(
                    title: 'Nhận lãi tháng',
                    subtitle: 'Kỳ 1/12 · CCTG 12 tháng',
                    trailing: Text('+3,1 tr'),
                  ),
              ],
            ),
          ),
          error: (e, _) => KhError(
            error: e,
            onRetry: () => ref.invalidate(custUpcomingProvider),
          ),
          data: (u) => u.items.isEmpty
              ? const KhNote('Chưa có khoản nào sắp nhận.')
              : KhList(
                  children: [for (final r in u.items.take(2)) KhReceiptRow(r)],
                ),
        ),
      ],
    );
  }
}

class _MyCertsSection extends ConsumerWidget {
  const _MyCertsSection({required this.holding});
  final int holding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certs = ref.watch(custHomeCertsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KhSection(
          'CCTG của tôi',
          actionLabel: 'Xem tất cả',
          onAction: () => context.go('/certificates'),
        ),
        const SizedBox(height: 12),
        certs.when(
          loading: () => Skeletonizer(
            child: KhList(
              children: [
                for (var i = 0; i < 2; i++)
                  const KhRow(
                    title: 'CCTG 12 tháng · 7,30%',
                    subtitle: 'Đáo hạn 02/10/2027',
                    trailing: Text('500 tr'),
                  ),
              ],
            ),
          ),
          error: (e, _) => KhError(
            error: e,
            onRetry: () => ref.invalidate(custHomeCertsProvider),
          ),
          data: (list) => list.isEmpty
              ? const KhNote(
                  'Bạn chưa có CCTG nào đang gửi. Liên hệ chuyên viên để được tư vấn.',
                )
              : KhList(children: [for (final c in list.take(3)) KhCertRow(c)]),
        ),
      ],
    );
  }
}
