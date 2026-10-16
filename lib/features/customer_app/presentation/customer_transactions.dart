import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/format.dart';
import '../../../core/utils/labels.dart';
import '../data/customer_app_dto.dart';
import 'customer_documents.dart';
import 'customer_labels.dart';
import 'customer_providers.dart';
import 'customer_support.dart';
import 'kh_format.dart';
import 'kh_theme.dart';
import 'kh_widgets.dart';

/// K06 – Giao dịch: lịch sử mua / tất toán / nhận lãi, lọc Tiền vào – Tiền ra, nhóm theo tháng.
class CustomerTransactionsScreen extends ConsumerStatefulWidget {
  const CustomerTransactionsScreen({super.key});

  @override
  ConsumerState<CustomerTransactionsScreen> createState() => _State();
}

class _State extends ConsumerState<CustomerTransactionsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        unawaited(ref.read(custTransactionsProvider.notifier).loadMore());
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
    final direction = ref.watch(custTrxDirectionProvider);
    final state = ref.watch(custTransactionsProvider);
    final notifier = ref.read(custTransactionsProvider.notifier);

    Widget body;
    if (state.loading) {
      body = const KhSkeleton();
    } else if (state.error != null) {
      body = KhError(error: state.error!, onRetry: notifier.refresh);
    } else if (state.isEmpty) {
      body = RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          children: const [
            SizedBox(
              height: 360,
              child: KhEmpty(
                icon: LucideIcons.history,
                title: 'Chưa có giao dịch',
                message:
                    'Lịch sử mua, tất toán và nhận lãi sẽ hiển thị tại đây.',
              ),
            ),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            ..._groups(state.items),
            if (state.loadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            if (state.loadMoreError != null)
              Center(
                child: TextButton(
                  onPressed: notifier.loadMore,
                  child: const Text('Không tải thêm được – thử lại'),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          KhTopBar(onBack: () => context.pop()),
          const KhLargeTitle(
            'Giao dịch',
            subtitle: 'Lịch sử mua và tất toán CCTG',
          ),
          KhChips<String?>(
            options: const [
              (null, 'Tất cả'),
              ('In', 'Tiền vào'),
              ('Out', 'Tiền ra'),
            ],
            value: direction,
            onChanged: (v) =>
                ref.read(custTrxDirectionProvider.notifier).set(v),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  List<Widget> _groups(List<CustTransaction> items) {
    final out = <Widget>[];
    var i = 0;
    while (i < items.length) {
      final key = khMonthGroup(items[i].createdAt);
      final group = <CustTransaction>[];
      while (i < items.length && khMonthGroup(items[i].createdAt) == key) {
        group.add(items[i++]);
      }
      if (out.isNotEmpty) out.add(const SizedBox(height: 16));
      out
        ..add(KhGroupLabel(key))
        ..add(const SizedBox(height: 10))
        ..add(KhList(children: [for (final t in group) _TrxRow(t)]));
    }
    return out;
  }
}

class _TrxRow extends StatelessWidget {
  const _TrxRow(this.t);
  final CustTransaction t;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    final incoming = custTrxIncoming(t.type);
    final note = custTrxStatusNote(t.status);
    return KhRow(
      minHeight: 68,
      leading: KhIconTile(
        incoming ? LucideIcons.download : LucideIcons.upload,
        tone: incoming ? KhTone.ok : KhTone.muted,
      ),
      title: custTrxTypeLabel(t.type),
      subtitle:
          '${formatDate(t.createdAt)}${note == null ? '' : ' · $note'}\n${t.trxNo}',
      wrapSubtitle: true,
      trailing: Text(
        khSignedMoney(t.amount, incoming: incoming),
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: incoming ? k.ok : k.ink,
          fontFeatures: KhType.nums,
        ),
      ),
      onTap: () => context.push('/transaction/${t.id}'),
    );
  }
}

/// Chi tiết giao dịch + hợp đồng của giao dịch.
class CustomerTransactionDetailScreen extends ConsumerWidget {
  const CustomerTransactionDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trx = ref.watch(custTransactionProvider(id));
    return Scaffold(
      body: Column(
        children: [
          KhTopBar(title: 'Chi tiết giao dịch', onBack: () => context.pop()),
          Expanded(
            child: trx.when(
              loading: () => const KhSkeleton(rows: 2),
              error: (e, _) => KhError(
                error: e,
                onRetry: () => ref.invalidate(custTransactionProvider(id)),
              ),
              data: (t) {
                final incoming = custTrxIncoming(t.type);
                final (label, kind) = _pill(t.status);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    KhList(
                      children: [
                        KhInfoRow('Loại giao dịch', custTrxTypeLabel(t.type)),
                        KhInfoRow(
                          'Số tiền',
                          khSignedMoney(t.amount, incoming: incoming),
                        ),
                        KhInfoRow('Mã giao dịch', t.trxNo),
                        KhInfoRow('Thời gian', formatDateTime(t.createdAt)),
                        if (t.contractCode != null)
                          KhInfoRow('Mã hợp đồng', t.contractCode!),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 56),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Trạng thái',
                                    style: KhType.s.copyWith(
                                      color: context.kh.ink2,
                                    ),
                                  ),
                                ),
                                KhPill(label, kind: kind),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (t.status == 'Failed') ...[
                      const SizedBox(height: 14),
                      const KhNote(
                        'Giao dịch không thành công. Vui lòng liên hệ chuyên viên của bạn để được hỗ trợ.',
                        icon: LucideIcons.circleAlert,
                        amber: true,
                      ),
                      const SizedBox(height: 10),
                      const KhCallSupportButton(),
                    ],
                    const SizedBox(height: 20),
                    CustDocumentsSection(
                      ownerType: 'transactions',
                      ownerId: id,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  (String, KhPillKind) _pill(String status) {
    final l = trxStatusOf(status);
    final kind = switch (l.tone) {
      Tone.success => KhPillKind.ok,
      Tone.danger => KhPillKind.bad,
      Tone.warning => KhPillKind.soon,
      Tone.info => KhPillKind.primary,
      Tone.neutral => KhPillKind.done,
    };
    return (l.label, kind);
  }
}
