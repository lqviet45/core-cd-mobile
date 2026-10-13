import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/models/paged.dart';
import '../../../core/money/money_action.dart';
import '../../../core/money/money_gate.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/ui/paged_list.dart';
import '../../../core/ui/snack.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../data/interest_dto.dart';

class _BucketNotifier extends Notifier<String> {
  @override
  String build() => 'due';

  // ignore: use_setters_to_change_properties
  void set(String v) => state = v;
}

final interestBucketProvider = NotifierProvider<_BucketNotifier, String>(
  _BucketNotifier.new,
);

class InterestDueNotifier extends PagedNotifier<InterestDueItem> {
  @override
  PagedState<InterestDueItem> build() {
    ref.watch(interestBucketProvider);
    return super.build();
  }

  @override
  Future<Paged<InterestDueItem>> fetch(int page) => ref
      .read(interestRepositoryProvider)
      .due(bucket: ref.read(interestBucketProvider), page: page);
}

final interestDueProvider =
    NotifierProvider<InterestDueNotifier, PagedState<InterestDueItem>>(
      InterestDueNotifier.new,
    );

final interestSummaryProvider = FutureProvider.autoDispose<InterestSummary>(
  (ref) => ref.watch(interestRepositoryProvider).summary(),
);

/// M09 – Chi lãi định kỳ: chọn các kỳ đến hạn/quá hạn rồi chi hàng loạt (sinh trắc ngay trước khi gửi).
class InterestScreen extends ConsumerStatefulWidget {
  const InterestScreen({super.key});

  @override
  ConsumerState<InterestScreen> createState() => _InterestScreenState();
}

class _InterestScreenState extends ConsumerState<InterestScreen> {
  final Map<String, InterestDueItem> _selected = {};
  bool _busy = false;

  Decimal get _total =>
      _selected.values.fold(Decimal.zero, (a, b) => a + b.amount);

  void _toggle(InterestDueItem i) => setState(() {
    if (_selected.remove(i.key) == null) _selected[i.key] = i;
  });

  Future<void> _pay() async {
    if (_busy || _selected.isEmpty) return;
    final items = _selected.values.toList();
    final total = _total;
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chi lãi ${items.length} kỳ?', style: sheet.text.titleLarge),
              const SizedBox(height: 12),
              SummaryCard(
                rows: [('Số kỳ lãi', '${items.length}')],
                total: ('Tổng tiền lãi', formatMoney(total)),
              ),
              const SizedBox(height: 8),
              Text(
                'Số tiền do hệ thống tính theo lịch chi lãi của từng CCTG.',
                style: sheet.text.bodySmall?.copyWith(
                  color: sheet.scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheet).pop(false),
                      child: const Text('Huỷ'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(sheet).pop(true),
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Tiếp tục'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    final result = await runMoneyAction<BulkResult>(
      context,
      ref,
      reason: 'Xác nhận chi lãi ${formatMoney(total)}',
      action: () => ref.read(interestRepositoryProvider).bulkPay(items),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null) return;
    _selected.clear();
    ref
      ..invalidate(interestSummaryProvider)
      ..invalidate(interestDueProvider);
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Kết quả chi lãi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đã chi ${result.succeededCount} kỳ · ${formatMoney(result.totalAmount)}',
              ),
              if (result.skippedCount > 0)
                Text('Bỏ qua ${result.skippedCount} kỳ (đã chi trước đó).'),
              if (result.failedCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${result.failedCount} kỳ không chi được:',
                  style: TextStyle(color: d.scheme.error),
                ),
                for (final i in result.items.where((e) => e.status == 'Failed'))
                  Text('• ${i.certificateNumber}: ${i.reason ?? 'Lỗi'}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
    if (mounted && result.failedCount == 0) {
      showSnack(context, 'Đã chi lãi ${result.succeededCount} kỳ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bucket = ref.watch(interestBucketProvider);
    final state = ref.watch(interestDueProvider);
    final notifier = ref.read(interestDueProvider.notifier);
    final summary = ref.watch(interestSummaryProvider).value;
    final canPay = ref.watch(canWriteProvider);
    final payable = bucket != 'paid' && canPay;
    final s = context.scheme;

    String label(String base, int? n) => n == null ? base : '$base · $n';

    return Scaffold(
      appBar: AppBar(title: const Text('Chi lãi định kỳ')),
      body: Column(
        children: [
          FilterChipsRow<String>(
            options: [
              ('due', label('Đến hạn', summary?.weekCount)),
              ('overdue', label('Quá hạn', summary?.overdueCount)),
              ('paid', 'Đã chi'),
            ],
            value: bucket,
            onChanged: (v) {
              _selected.clear();
              ref.read(interestBucketProvider.notifier).set(v);
            },
          ),
          if (payable && _selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: AppCard(
                kind: CardKind.primaryContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('Đã chọn ${_selected.length} kỳ')),
                    Text(formatMoney(_total), style: context.text.titleLarge),
                  ],
                ),
              ),
            ),
          Expanded(
            child: PagedListView<InterestDueItem>(
              state: state,
              onRefresh: () async {
                ref.invalidate(interestSummaryProvider);
                await notifier.refresh();
              },
              onLoadMore: notifier.loadMore,
              emptyTitle: bucket == 'paid'
                  ? 'Chưa có kỳ lãi nào được chi'
                  : 'Không có kỳ lãi nào cần chi',
              separatorHeight: 8,
              itemBuilder: (context, i) {
                final on = _selected.containsKey(i.key);
                final overdue = i.status == 'Overdue';
                return Semantics(
                  selected: on,
                  child: AppCard(
                    kind: CardKind.outlined,
                    onTap: payable ? () => _toggle(i) : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        if (payable) ...[
                          Icon(
                            on ? LucideIcons.squareCheck : LucideIcons.square,
                            color: on ? s.primary : s.outline,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i.customerName,
                                style: context.text.titleMedium,
                              ),
                              Text.rich(
                                TextSpan(
                                  style: context.text.bodySmall?.copyWith(
                                    color: s.onSurfaceVariant,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          '${i.method == 'Monthly' ? 'Hàng tháng' : 'Hàng quý'} · '
                                          'kỳ ${i.periodIndex}/${i.periodTotal} · ',
                                    ),
                                    TextSpan(
                                      text: i.status == 'Paid'
                                          ? 'đã chi'
                                          : overdue
                                          ? 'quá hạn ${i.daysOverdue} ngày'
                                          : i.status == 'Today'
                                          ? 'hôm nay'
                                          : formatDaysFrom(
                                              i.dueDate,
                                              todayBusinessDate(),
                                            ),
                                      style: overdue
                                          ? TextStyle(
                                              color: s.error,
                                              fontWeight: FontWeight.w700,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                i.certificateNumber,
                                style: context.text.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  color: s.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${formatCompact(i.amount)} ₫',
                          style: context.text.titleMedium,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: payable
          ? BottomBar(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selected.isEmpty || _busy ? null : _pay,
                  icon: const Icon(LucideIcons.coins, size: 18),
                  label: Text(
                    _selected.isEmpty
                        ? 'Chọn kỳ lãi để chi'
                        : 'Chi lãi ${_selected.length} kỳ',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
