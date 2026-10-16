import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/format.dart';
import '../data/customer_app_dto.dart';
import 'customer_common.dart';
import 'customer_providers.dart';
import 'kh_format.dart';
import 'kh_theme.dart';
import 'kh_widgets.dart';

/// K05 – Lịch nhận tiền: kỳ lãi và gốc/lãi đáo hạn sẽ về, lọc 30 ngày / 90 ngày / cả năm, nhóm theo tháng.
class CustomerCalendarScreen extends ConsumerStatefulWidget {
  const CustomerCalendarScreen({super.key});

  @override
  ConsumerState<CustomerCalendarScreen> createState() => _State();
}

class _State extends ConsumerState<CustomerCalendarScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    final upcoming = ref.watch(custUpcomingProvider);

    Future<void> refresh() async {
      ref.invalidate(custUpcomingProvider);
      try {
        await ref.read(custUpcomingProvider.future);
      } on Object {
        // Lỗi đã hiển thị bởi trạng thái error của provider.
      }
    }

    return Scaffold(
      body: Column(
        children: [
          const KhTopBar(height: 56),
          const KhLargeTitle(
            'Lịch nhận tiền',
            subtitle: 'Lãi và gốc sẽ về tài khoản của bạn',
          ),
          KhChips<int>(
            options: const [(30, '30 ngày'), (90, '90 ngày'), (366, 'Cả năm')],
            value: _days,
            onChanged: (v) => setState(() => _days = v),
          ),
          Expanded(
            child: upcoming.when(
              loading: () => const KhSkeleton(rows: 2),
              error: (e, _) => KhError(error: e, onRetry: refresh),
              data: (u) {
                final limit = todayBusinessDate().add(Duration(days: _days));
                final items = u.items
                    .where((i) => !i.date.isAfter(limit))
                    .toList();
                final total = items.fold(Decimal.zero, (a, i) => a + i.amount);
                final horizon = _days == 366 ? '12 tháng' : '$_days ngày';
                return RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      KhCard(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const KhIconTile(LucideIcons.wallet, size: 48),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sẽ nhận trong $horizon tới',
                                    style: KhType.s.copyWith(color: k.ink2),
                                  ),
                                  Text(
                                    formatMoney(total),
                                    style: KhType.t1.copyWith(
                                      color: k.ink,
                                      fontFeatures: KhType.nums,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${items.length} khoản',
                              style: KhType.c.copyWith(color: k.ink3),
                            ),
                          ],
                        ),
                      ),
                      if (items.isEmpty)
                        const SizedBox(
                          height: 280,
                          child: KhEmpty(
                            icon: LucideIcons.calendarCheck,
                            title: 'Chưa có khoản nào sắp nhận',
                            message: 'Thử chọn khoảng thời gian dài hơn.',
                          ),
                        )
                      else
                        ..._groups(items),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Nhóm theo tháng (danh sách đã sắp theo ngày): nhãn tháng + một khối hàng.
  List<Widget> _groups(List<CustReceipt> items) {
    final out = <Widget>[];
    var i = 0;
    while (i < items.length) {
      final key = khMonthGroup(items[i].date);
      final group = <CustReceipt>[];
      while (i < items.length && khMonthGroup(items[i].date) == key) {
        group.add(items[i++]);
      }
      out
        ..add(const SizedBox(height: 20))
        ..add(KhGroupLabel(key))
        ..add(const SizedBox(height: 10))
        ..add(
          KhList(
            children: [for (final r in group) KhReceiptRow(r, detailed: true)],
          ),
        );
    }
    return out;
  }
}
