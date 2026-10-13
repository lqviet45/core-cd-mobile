import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/money/idempotency.dart';
import '../../../core/money/money_action.dart';
import '../../../core/ui/money_field.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../customers/data/customer_dto.dart';
import '../../customers/presentation/customer_picker.dart';
import '../../transactions/data/trade_dto.dart';
import '../../transactions/presentation/transaction_screens.dart';
import 'trading_providers.dart';

/// Đọc "0,1" / "0.1" (%/năm) thành tỉ lệ thập phân 0,001; `null` nếu không hợp lệ hoặc ngoài 0–100%.
Decimal? parseRatePercent(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = Decimal.tryParse(t);
  if (v == null || v < Decimal.zero || v > Decimal.fromInt(100)) return null;
  return (v / Decimal.fromInt(100)).toDecimal(scaleOnInfinitePrecision: 10);
}

/// M17–M18 – Bán / Tất toán: xem trước do máy chủ tính rồi xác nhận bằng sinh trắc.
class SellScreen extends ConsumerStatefulWidget {
  const SellScreen({super.key, this.customerId});
  final String? customerId;

  @override
  ConsumerState<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends ConsumerState<SellScreen> {
  Customer? _customer;
  String _type = 'All';
  final _qty = TextEditingController(text: '1');
  final _amount = TextEditingController();
  final _rate = TextEditingController(text: '0,1');
  DateTime _date = todayBusinessDate();

  Timer? _debounce;
  SellParams? _debounced;
  SellPreview? _last;

  // Idempotency-Key gắn với bộ tham số: mở lại hộp xác nhận cho CÙNG lệnh thì dùng lại khoá (không tạo lệnh trùng
  // nếu lần trước mất mạng giữa chừng); đổi tham số thì là lệnh khác nên sinh khoá mới.
  SellParams? _keyParams;
  String? _key;
  String _keyFor(SellParams p) {
    if (_key == null || _keyParams != p) {
      _key = newIdempotencyKey();
      _keyParams = p;
    }
    return _key!;
  }

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
      if (mounted) {
        setState(() => _customer = c);
        _schedule();
      }
    } on Object {
      // Người dùng tự chọn khách hàng.
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _qty.dispose();
    _amount.dispose();
    _rate.dispose();
    super.dispose();
  }

  SellParams? get _params {
    final c = _customer;
    final rate = parseRatePercent(_rate.text);
    if (c == null || rate == null) return null;
    final qty = int.tryParse(_qty.text);
    final amount = parseVnd(_amount.text);
    if (_type == 'Quantity' && (qty == null || qty <= 0)) return null;
    if (_type == 'Amount' && (amount == null || amount <= Decimal.zero)) {
      return null;
    }
    return SellParams(
      customerId: c.id,
      sellType: _type,
      quantity: _type == 'Quantity' ? qty : null,
      targetAmount: _type == 'Amount' ? amount : null,
      redemptionDate: _date,
      demandRate: rate,
    );
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _debounced = _params);
    });
    setState(() {}); // cập nhật trạng thái "đang tính"
  }

  Future<void> _pickDate() async {
    final today = todayBusinessDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_date.year, _date.month, _date.day),
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'Ngày tất toán',
    );
    if (picked != null) {
      setState(
        () => _date = DateTime.utc(picked.year, picked.month, picked.day),
      );
      _schedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    final params = _params;
    final d = _debounced;
    final preview = d == null ? null : ref.watch(sellPreviewProvider(d));
    final fresh = preview?.value;
    if (fresh != null) _last = fresh;
    final p = d == null ? null : _last;
    final stale = params != d || (preview?.isLoading ?? false);
    final ready = p != null && p.canSubmit && !stale && params != null;

    return Scaffold(
      appBar: AppBar(
        leading: IconBtn(
          icon: LucideIcons.x,
          label: 'Đóng',
          onPressed: () => context.pop(),
        ),
        title: const Text('Bán / Tất toán'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          CustomerPicker(
            value: _customer,
            onChanged: (c) {
              setState(() {
                _customer = c;
                _last = null;
              });
              _schedule();
            },
          ),
          if (_customer != null && p != null) ...[
            const SizedBox(height: 8),
            Text(
              p.eligibleCount == 0
                  ? 'Khách hàng không có CCTG nào đủ điều kiện bán.'
                  : '${p.eligibleCount} CCTG đủ điều kiện · '
                        '${formatCompact(p.eligibleTotalPrincipal)} ₫ · ưu tiên CCTG đáo hạn sớm nhất',
              style: context.text.bodySmall?.copyWith(
                color: p.eligibleCount == 0 ? s.error : s.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'All', label: Text('Tất cả')),
              ButtonSegment(value: 'Quantity', label: Text('Số lượng')),
              ButtonSegment(value: 'Amount', label: Text('Số tiền')),
            ],
            selected: {_type},
            onSelectionChanged: (v) {
              setState(() => _type = v.first);
              _schedule();
            },
          ),
          const SizedBox(height: 16),
          if (_type == 'Quantity')
            TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Số lượng CCTG'),
              onChanged: (_) => _schedule(),
            ),
          if (_type == 'Amount')
            MoneyField(
              controller: _amount,
              label: 'Tổng mệnh giá cần bán',
              helperText: 'Chọn đến khi đủ số tiền, có thể vượt một CCTG cuối.',
              onChanged: (_) => _schedule(),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ngày tất toán',
                    ),
                    child: Text(formatDate(_date)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _rate,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Lãi KKH (%/năm)',
                    errorText: parseRatePercent(_rate.text) == null
                        ? 'Nhập 0–100'
                        : null,
                  ),
                  onChanged: (_) => _schedule(),
                ),
              ),
            ],
          ),
          if (preview != null && preview.hasError) ...[
            const SizedBox(height: 16),
            ErrorState(
              error: preview.error!,
              onRetry: () => ref.invalidate(sellPreviewProvider(d!)),
            ),
          ],
          if (p != null && p.issues.isNotEmpty) ...[
            const SizedBox(height: 16),
            NoteCard(
              kind: CardKind.error,
              icon: LucideIcons.triangleAlert,
              text: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final i in p.issues) Text('• $i')],
              ),
            ),
          ],
          if (p != null && p.items.isNotEmpty) ...[
            const SectionHeader('Sẽ tất toán'),
            Opacity(
              opacity: stale ? .5 : 1,
              child: ListGroup(
                children: [
                  for (final i in p.items)
                    ListRow(
                      title: i.certificateNumber,
                      subtitle:
                          '${i.isEarly ? 'Trước hạn' : 'Đúng hạn'} · ${formatCompact(i.principal)} ₫',
                      trailing: Text(
                        '${formatCompact(i.netAmount)} ₫',
                        style: context.text.titleMedium,
                      ),
                    ),
                ],
              ),
            ),
            if (p.earlyCount > 0) ...[
              const SizedBox(height: 12),
              NoteCard(
                icon: LucideIcons.triangleAlert,
                text: Text(
                  '${p.earlyCount} CCTG tất toán trước hạn: khách hàng mất '
                  '${formatMoney(p.totalLostInterest)} lãi cam kết.',
                ),
              ),
            ],
          ],
        ],
      ),
      bottomNavigationBar: BottomBar(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tổng thực nhận',
                    style: context.text.bodySmall?.copyWith(
                      color: s.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    p == null ? '—' : formatMoney(p.totalNetAmount),
                    style: context.text.titleLarge,
                  ),
                ],
              ),
            ),
            FilledButton(
              // Theme đặt chiều rộng tối thiểu = vô hạn; trong Row phải đặt lại.
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: ready
                  ? () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => _SellConfirmSheet(
                        customer: _customer!,
                        params: params,
                        preview: p,
                        idempotencyKey: _keyFor(params),
                      ),
                    )
                  : null,
              child: const Text('Xem lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellConfirmSheet extends ConsumerStatefulWidget {
  const _SellConfirmSheet({
    required this.customer,
    required this.params,
    required this.preview,
    required this.idempotencyKey,
  });
  final Customer customer;
  final SellParams params;
  final SellPreview preview;
  final String idempotencyKey;

  @override
  ConsumerState<_SellConfirmSheet> createState() => _SellConfirmSheetState();
}

class _SellConfirmSheetState extends ConsumerState<_SellConfirmSheet> {
  bool _busy = false;

  Future<void> _submit() async {
    if (_busy) return;
    final p = widget.preview;
    setState(() => _busy = true);
    final created = await runMoneyAction(
      context,
      ref,
      reason: 'Xác nhận bán / tất toán ${formatMoney(p.totalNetAmount)}',
      idempotent: true,
      action: () => ref
          .read(transactionRepositoryProvider)
          .sell(widget.params, idempotencyKey: widget.idempotencyKey),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (created != null) {
      ref.invalidate(transactionsProvider);
      Navigator.of(context).pop();
      context.go('/transactions/${created.transactionId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.preview;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tạo lệnh bán?', style: context.text.titleLarge),
            const SizedBox(height: 12),
            SummaryCard(
              rows: [
                ('Khách hàng', widget.customer.fullName),
                ('Số CCTG tất toán', '${p.items.length}'),
                ('Gốc', formatMoney(p.totalPrincipal)),
                ('Lãi', '+ ${formatMoney(p.totalInterest)}'),
                (
                  'Trừ lãi đã chi',
                  '− ${formatMoney(p.totalInterestAlreadyPaid)}',
                ),
                if (p.totalFee > Decimal.zero)
                  ('Phí tất toán sớm', '− ${formatMoney(p.totalFee)}'),
              ],
              total: ('Thực nhận', formatMoney(p.totalNetAmount)),
            ),
            if (p.earlyCount > 0) ...[
              const SizedBox(height: 12),
              NoteCard(
                icon: LucideIcons.triangleAlert,
                text: Text(
                  '${p.earlyCount} CCTG tất toán trước hạn, khách hàng mất '
                  '${formatMoney(p.totalLostInterest)} lãi cam kết.',
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Lệnh được xử lý nền và không thể hoàn tác.',
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: const Text('Huỷ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(_busy ? 'Đang gửi…' : 'Xác nhận'),
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
