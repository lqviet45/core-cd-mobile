import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/models/paged.dart';
import '../../../core/money/money_gate.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/ui/paged_list.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/labels.dart';
import '../../dashboard/data/dashboard_dto.dart';

final transactionStatusFilterProvider =
    NotifierProvider<_StatusNotifier, String>(_StatusNotifier.new);

class _StatusNotifier extends Notifier<String> {
  @override
  String build() => '';

  // ignore: use_setters_to_change_properties
  void set(String v) => state = v;
}

class TransactionsNotifier extends PagedNotifier<Transaction> {
  @override
  PagedState<Transaction> build() {
    ref.watch(transactionStatusFilterProvider);
    return super.build();
  }

  @override
  Future<Paged<Transaction>> fetch(int page) => ref
      .read(transactionRepositoryProvider)
      .list(page: page, status: ref.read(transactionStatusFilterProvider));
}

final transactionsProvider =
    NotifierProvider<TransactionsNotifier, PagedState<Transaction>>(
      TransactionsNotifier.new,
    );

/// "Hôm nay" / "Hôm qua" / "dd/MM/yyyy" theo giờ máy.
String _dayLabel(DateTime d, DateTime now) {
  final l = d.toLocal();
  final a = DateTime(l.year, l.month, l.day);
  final b = DateTime(now.year, now.month, now.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return 'Hôm nay';
  if (diff == 1) return 'Hôm qua';
  return formatDate(DateTime.utc(l.year, l.month, l.day));
}

String _time(DateTime d) {
  final l = d.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

bool _isSell(String type) => type.startsWith('Sell');

/// M17 – Lịch sử giao dịch (chỉ đọc ở bản này).
class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transactionsProvider);
    final status = ref.watch(transactionStatusFilterProvider);
    final notifier = ref.read(transactionsProvider.notifier);
    final now = DateTime.now();

    // Nhóm theo ngày: chèn tiêu đề ngày trước mục đầu tiên của mỗi ngày.
    final rows = <Object>[];
    String? last;
    for (final t in state.items) {
      final label = _dayLabel(t.createdAt, now);
      if (label != last) {
        rows.add(label);
        last = label;
      }
      rows.add(t);
    }

    return Scaffold(
      body: Column(
        children: [
          BigHeader(
            'Giao dịch',
            actions: [
              if (ref.watch(canWriteProvider))
                IconBtn(
                  icon: LucideIcons.plus,
                  label: 'Giao dịch mới',
                  onPressed: () => _showNewTrade(context),
                ),
            ],
          ),
          FilterChipsRow<String>(
            options: const [
              ('', 'Tất cả'),
              ('Processing', 'Đang xử lý'),
              ('Pending', 'Chờ xử lý'),
              ('Failed', 'Thất bại'),
            ],
            value: status,
            onChanged: (v) =>
                ref.read(transactionStatusFilterProvider.notifier).set(v),
          ),
          Expanded(
            child: PagedListView<Object>(
              state: PagedState<Object>(
                items: rows,
                page: state.page,
                total: state.total,
                hasMore: state.hasMore,
                loading: state.loading,
                loadingMore: state.loadingMore,
                error: state.error,
                loadMoreError: state.loadMoreError,
              ),
              onRefresh: notifier.refresh,
              onLoadMore: notifier.loadMore,
              emptyTitle: 'Chưa có giao dịch',
              emptyMessage: 'Giao dịch mới sẽ hiện ở đây.',
              separatorHeight: 0,
              itemBuilder: (context, row) => row is String
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: SectionHeader(row),
                    )
                  : _TransactionRow(row as Transaction),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow(this.t);
  final Transaction t;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    final status = trxStatusOf(t.status);
    final failed = t.status == 'Failed';
    return Container(
      decoration: BoxDecoration(
        color: s.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: s.outlineVariant)),
      ),
      child: ListRow(
        lead: Lead(
          icon: _isSell(t.type) ? LucideIcons.upload : LucideIcons.download,
          kind: failed ? LeadKind.error : LeadKind.primary,
        ),
        onTap: () => context.push('/transactions/${t.id}'),
        title: '${trxTypeLabel(t.type)} · ${t.cif}',
        subtitle: '${_time(t.createdAt)} · ${t.channel}',
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${formatCompact(t.amount)} ₫',
              style: context.text.titleMedium,
            ),
            const SizedBox(height: 2),
            StatusChip(status),
          ],
        ),
      ),
    );
  }
}

void _showNewTrade(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (sheet) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(LucideIcons.download),
          title: const Text('Mua CCTG'),
          onTap: () {
            Navigator.of(sheet).pop();
            unawaited(context.push('/trade/buy'));
          },
        ),
        ListTile(
          leading: const Icon(LucideIcons.upload),
          title: const Text('Bán / Tất toán'),
          onTap: () {
            Navigator.of(sheet).pop();
            unawaited(context.push('/trade/sell'));
          },
        ),
      ],
    ),
  ),
);
