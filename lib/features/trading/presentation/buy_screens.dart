import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/money/money_action.dart';
import '../../../core/ui/money_field.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/labels.dart';
import '../../customers/presentation/customer_picker.dart';
import '../../lots/data/lot_dto.dart';
import 'trading_providers.dart';

/// Khung chung của luồng mua: thanh tiêu đề có bước + thanh tiến độ.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.step,
    required this.leadingClose,
    required this.body,
    required this.bottom,
  });

  final String title;
  final int step;
  final bool leadingClose;
  final Widget body;
  final Widget bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconBtn(
        icon: leadingClose ? LucideIcons.x : LucideIcons.chevronLeft,
        label: leadingClose ? 'Đóng' : 'Quay lại',
        onPressed: () => context.pop(),
      ),
      title: Text(title),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              'Bước $step/3',
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: AppProgress(step / 3, semanticLabel: 'Bước $step trên 3'),
        ),
      ),
    ),
    body: body,
    bottomNavigationBar: BottomBar(child: bottom),
  );
}

/// M13 – Mua CCTG, bước 1: chọn khách hàng và đợt phát hành.
class BuyLotScreen extends ConsumerStatefulWidget {
  const BuyLotScreen({super.key, this.customerId, this.lotId});

  /// Điền sẵn khi mở từ chi tiết khách hàng / đợt phát hành.
  final String? customerId;
  final String? lotId;

  @override
  ConsumerState<BuyLotScreen> createState() => _BuyLotScreenState();
}

class _BuyLotScreenState extends ConsumerState<BuyLotScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(Future.microtask(_prefill));
  }

  Future<void> _prefill() async {
    final id = widget.customerId;
    if (id == null) return;
    try {
      final c = await ref.read(customerRepositoryProvider).get(id);
      if (mounted) ref.read(buyDraftProvider.notifier).setCustomer(c);
    } on Object {
      // Không điền sẵn được thì người dùng tự tìm.
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(buyDraftProvider);
    final notifier = ref.read(buyDraftProvider.notifier);
    final lots = ref.watch(openLotsProvider);
    final s = context.scheme;

    // Chọn sẵn lô theo tham số khi danh sách đã tải xong.
    ref.listen(openLotsProvider, (_, next) {
      final lotId = widget.lotId;
      final l = next.value;
      if (lotId != null &&
          l != null &&
          ref.read(buyDraftProvider).lot == null) {
        for (final x in l) {
          if (x.id == lotId) notifier.setLot(x);
        }
      }
    });

    return _StepScaffold(
      title: 'Mua CCTG',
      step: 1,
      leadingClose: true,
      bottom: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: draft.customer != null && draft.lot != null
              ? () => context.push('/trade/buy/amount')
              : null,
          child: const Text('Tiếp tục'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('Khách hàng', style: context.text.titleMedium),
          const SizedBox(height: 8),
          CustomerPicker(
            value: draft.customer,
            onChanged: notifier.setCustomer,
          ),
          const SizedBox(height: 20),
          Text('Chọn đợt phát hành', style: context.text.titleMedium),
          const SizedBox(height: 8),
          lots.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorState(
              error: e,
              onRetry: () => ref.invalidate(openLotsProvider),
            ),
            data: (list) => list.isEmpty
                ? const EmptyState(
                    title: 'Chưa có đợt phát hành đang mở',
                    icon: LucideIcons.layers,
                  )
                : Column(
                    children: [
                      for (final l in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LotChoice(
                            lot: l,
                            selected: draft.lot?.id == l.id,
                            onTap: () => notifier.setLot(l),
                            scheme: s,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _LotChoice extends StatelessWidget {
  const _LotChoice({
    required this.lot,
    required this.selected,
    required this.onTap,
    required this.scheme,
  });
  final Lot lot;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      borderRadius: BorderRadius.circular(Tokens.radiusCard),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Tokens.radiusCard),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${lot.termName} · ${formatPercent(lot.annualRatePct)}/năm',
                    style: context.text.titleMedium,
                  ),
                ),
                if (lot.isNearlySoldOut)
                  const StatusChip((label: 'Sắp hết', tone: Tone.warning))
                else if (selected)
                  Icon(LucideIcons.check, color: scheme.primary, size: 20),
              ],
            ),
            Text(
              '${paymentMethodLabel(lot.paymentMethod)} · đáo hạn '
              '${formatDate(lot.maturityDate)}',
              style: context.text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            AppProgress(
              lot.issuedPercent / 100,
              warn: lot.isNearlySoldOut,
              semanticLabel: 'Đã phát hành ${lot.issuedPercent.round()}%',
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Còn ${formatCompact(lot.remainingFaceValue)} ₫',
                    style: context.text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Tối thiểu ${formatCompact(lot.minPurchaseAmount)} ₫',
                    style: context.text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// M14 – bước 2: nhập số tiền và ngày phát hành.
class BuyAmountScreen extends ConsumerStatefulWidget {
  const BuyAmountScreen({super.key});

  @override
  ConsumerState<BuyAmountScreen> createState() => _BuyAmountScreenState();
}

class _BuyAmountScreenState extends ConsumerState<BuyAmountScreen> {
  final _amount = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = ref.read(buyDraftProvider).principal;
    if (p != null) _amount.text = groupThousands(p.toBigInt().toString());
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = ref.read(buyDraftProvider);
    final lot = d.lot!;
    final today = todayBusinessDate();
    final last = today.isBefore(lot.maturityDate) ? today : lot.maturityDate;
    final first = lot.issueDate.isAfter(last) ? last : lot.issueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: d.issueDate.isBefore(first)
          ? first
          : (d.issueDate.isAfter(last) ? last : d.issueDate),
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(last.year, last.month, last.day),
      helpText: 'Ngày phát hành',
    );
    if (picked != null) {
      ref
          .read(buyDraftProvider.notifier)
          .setIssueDate(DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  void _setAmount(Decimal v) {
    _amount.text = groupThousands(v.toBigInt().toString());
    ref.read(buyDraftProvider.notifier).setPrincipal(v);
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(buyDraftProvider);
    final lot = d.lot;
    if (lot == null) {
      // Vào thẳng bước 2 mà chưa có nháp (ví dụ khôi phục điều hướng) → quay về bước 1.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/trade/buy');
      });
      return const Scaffold();
    }
    final s = context.scheme;
    final quick = <Decimal>{
      lot.minPurchaseAmount,
      Decimal.fromInt(10000000),
      Decimal.fromInt(50000000),
      Decimal.fromInt(100000000),
      Decimal.fromInt(500000000),
    }.where((v) => v >= lot.minPurchaseAmount && v <= lot.remainingFaceValue);

    return _StepScaffold(
      title: 'Mua CCTG',
      step: 2,
      leadingClose: false,
      bottom: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: d.amountValid
              ? () => context.push('/trade/buy/review')
              : null,
          child: const Text('Xem lại'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Số tiền mua · lô ${lot.termName} ${formatPercent(lot.annualRatePct)}',
            style: context.text.bodyMedium?.copyWith(color: s.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          MoneyField(
            controller: _amount,
            label: 'Số tiền mua',
            autofocus: true,
            errorText: d.principalError,
            helperText:
                'Tối thiểu ${formatMoney(lot.minPurchaseAmount)} · còn lại '
                '${formatCompact(lot.remainingFaceValue)} ₫',
            onChanged: ref.read(buyDraftProvider.notifier).setPrincipal,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final v in quick)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(formatCompact(v)),
                      onPressed: () => _setAmount(v),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Ngày phát hành',
                errorText: d.dateError,
                suffixIcon: const Icon(LucideIcons.calendar),
              ),
              child: Text(formatDate(d.issueDate)),
            ),
          ),
          if (d.principal != null && d.dateError == null) ...[
            const SizedBox(height: 16),
            SummaryCard(
              rows: [
                ('Kỳ hạn thực tế', '${d.termDays} ngày'),
                ('Lãi suất', '${formatPercent(lot.annualRatePct)}/năm'),
                ('Lãi dự kiến', formatMoney(d.interest)),
              ],
              total: (
                'Nhận khi đáo hạn',
                formatMoney(d.principal! + d.interest),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// M15 – bước 3: xem lại và xác nhận bằng sinh trắc.
class BuyReviewScreen extends ConsumerStatefulWidget {
  const BuyReviewScreen({super.key});

  @override
  ConsumerState<BuyReviewScreen> createState() => _BuyReviewScreenState();
}

class _BuyReviewScreenState extends ConsumerState<BuyReviewScreen> {
  bool _busy = false;

  Future<void> _submit() async {
    if (_busy) return; // chống bấm đúp (Idempotency-Key là lớp bảo vệ thứ hai)
    final d = ref.read(buyDraftProvider);
    setState(() => _busy = true);
    final created = await runMoneyAction(
      context,
      ref,
      reason: 'Xác nhận mua CCTG ${formatMoney(d.principal)}',
      idempotent: true,
      action: () => ref
          .read(transactionRepositoryProvider)
          .buy(
            customerId: d.customer!.id,
            lotId: d.lot!.id,
            principal: d.principal!,
            issueDate: d.issueDate,
            idempotencyKey: d.key,
          ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (created != null) {
      ref.invalidate(openLotsProvider);
      context.go('/transactions/${created.transactionId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(buyDraftProvider);
    final lot = d.lot;
    final customer = d.customer;
    final principal = d.principal;
    if (lot == null || customer == null || principal == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/trade/buy');
      });
      return const Scaffold();
    }
    final s = context.scheme;
    return _StepScaffold(
      title: 'Xác nhận lệnh mua',
      step: 3,
      leadingClose: false,
      bottom: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.fingerprint),
          label: Text(_busy ? 'Đang gửi lệnh…' : 'Xác nhận bằng sinh trắc'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            kind: CardKind.primary,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Text(
                  'Bạn sắp mua',
                  style: context.text.bodyMedium?.copyWith(
                    color: s.onPrimary.withValues(alpha: .85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatMoney(principal)} ',
                  style: context.text.headlineMedium?.copyWith(
                    color: s.onPrimary,
                  ),
                ),
                Text(
                  'CCTG ${lot.termName} · ${formatPercent(lot.annualRatePct)}/năm',
                  style: context.text.bodyMedium?.copyWith(
                    color: s.onPrimary.withValues(alpha: .85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ListGroup(
            children: [
              InfoRow('Khách hàng', customer.fullName),
              InfoRow('Ngày phát hành', formatDate(d.issueDate)),
              InfoRow('Ngày đáo hạn', formatDate(lot.maturityDate)),
              InfoRow('Lãi dự kiến', formatMoney(d.interest)),
              InfoRow('Nhận khi đáo hạn', formatMoney(principal + d.interest)),
            ],
          ),
          const SizedBox(height: 16),
          const NoteCard(
            text: Text(
              'Lệnh được xử lý nền. Bạn sẽ thấy kết quả ở màn Theo dõi. '
              'Bấm đúp sẽ không tạo lệnh trùng.',
            ),
          ),
        ],
      ),
    );
  }
}
