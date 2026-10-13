import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/money/money_action.dart';
import '../../../core/money/money_gate.dart';
import '../../../core/ui/snack.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/labels.dart';
import '../../trading/presentation/sell_screen.dart' show parseRatePercent;
import '../data/certificate_dto.dart';
import 'certificate_providers.dart';

/// Có thể tất toán trước hạn: CCTG còn hiệu lực và chưa đến ngày đáo hạn.
bool canRedeemEarly(Certificate c, DateTime today) =>
    (c.status == 'Active' || c.status == 'NearMaturity') &&
    today.isBefore(c.maturityDate);

/// Có thể tất toán đúng hạn: đã đến/qua ngày đáo hạn và chưa tất toán.
bool canRedeemAtMaturity(Certificate c, DateTime today) =>
    (c.status == 'Active' ||
        c.status == 'NearMaturity' ||
        c.status == 'Matured') &&
    !today.isBefore(c.maturityDate);

void _afterChange(WidgetRef ref, String id) {
  ref
    ..invalidate(certificateProvider(id))
    ..invalidate(interestScheduleProvider(id))
    ..invalidate(certificatesProvider);
}

Future<void> _show(BuildContext context, Widget sheet) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(child: SingleChildScrollView(child: sheet)),
      ),
    );

Future<void> showEarlyRedemptionSheet(BuildContext context, Certificate c) =>
    _show(context, _EarlySheet(c));

Future<void> showMaturitySheet(BuildContext context, Certificate c) =>
    _show(context, _MaturitySheet(c));

Future<void> showPayInterestSheet(BuildContext context, Certificate c) =>
    _show(context, _InterestSheet(c));

/// Thanh hành động cố định ở đáy chi tiết CCTG (ẩn với Viewer; khoá khi đang phong tỏa), theo thiết kế
/// `MobCertDetail`: "Chi lãi" (viền) + "Tất toán sớm"/"Tất toán đúng hạn".
class CertificateActionBar extends ConsumerWidget {
  const CertificateActionBar(this.c, {super.key});
  final Certificate c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canWriteProvider) ||
        c.isRedeemed ||
        c.status == 'Cancelled') {
      return const SizedBox.shrink();
    }
    final today = todayBusinessDate();
    final early = canRedeemEarly(c, today);
    final maturity = canRedeemAtMaturity(c, today);
    final schedule = c.paymentMethod == 'AtMaturity'
        ? null
        : ref.watch(interestScheduleProvider(c.id)).value;
    final hasOpenInterest =
        schedule != null &&
        schedule.periods.any(
          (p) => p.status != 'Paid' && p.status != 'Blocked',
        );
    if (!early && !maturity && !hasOpenInterest) {
      return const SizedBox.shrink();
    }

    final buttons = <Widget>[
      if (hasOpenInterest)
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: c.isOnHold
                ? null
                : () => showPayInterestSheet(context, c),
            icon: const Icon(LucideIcons.coins, size: 18),
            label: const Text('Chi lãi'),
          ),
        ),
      if (early)
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              backgroundColor: context.scheme.error,
              foregroundColor: context.scheme.onError,
            ),
            onPressed: c.isOnHold
                ? null
                : () => showEarlyRedemptionSheet(context, c),
            icon: const Icon(LucideIcons.circleX, size: 18),
            label: const Text('Tất toán sớm'),
          ),
        ),
      if (maturity)
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: c.isOnHold ? null : () => showMaturitySheet(context, c),
            icon: const Icon(LucideIcons.circleCheck, size: 18),
            label: const Text('Tất toán đúng hạn'),
          ),
        ),
    ];

    return BottomBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.isOnHold)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NoteCard(
                icon: LucideIcons.lock,
                text: Text(
                  'CCTG đang phong tỏa ${formatMoney(c.holdAmount)}: không thể '
                  'tất toán hay chi lãi.',
                ),
              ),
            ),
          Row(
            children: [
              for (final (i, b) in buttons.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                b,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Nút xác nhận có biểu tượng sinh trắc dùng chung cho các bảng.
class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.label,
    required this.busy,
    required this.onConfirm,
    this.danger = false,
  });
  final String label;
  final bool busy;
  final VoidCallback? onConfirm;
  final bool danger;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Huỷ'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: FilledButton.icon(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: context.scheme.error,
                  foregroundColor: context.scheme.onError,
                )
              : null,
          onPressed: busy ? null : onConfirm,
          icon: const Icon(Icons.fingerprint),
          label: Text(busy ? 'Đang xử lý…' : label),
        ),
      ),
    ],
  );
}

class _SheetPad extends StatelessWidget {
  const _SheetPad({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.text.titleLarge),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

/// M07–M08 – Tất toán trước hạn.
class _EarlySheet extends ConsumerStatefulWidget {
  const _EarlySheet(this.cert);
  final Certificate cert;

  @override
  ConsumerState<_EarlySheet> createState() => _EarlySheetState();
}

typedef _EarlyKey = (String, DateTime, Decimal);

final _earlyPreviewProvider = FutureProvider.autoDispose
    .family<EarlyRedemptionPreview, _EarlyKey>(
      (ref, k) => ref
          .watch(certificateRepositoryProvider)
          .previewEarly(k.$1, date: k.$2, demandRate: k.$3),
    );

class _EarlySheetState extends ConsumerState<_EarlySheet> {
  DateTime _date = todayBusinessDate();
  final _rate = TextEditingController(text: '0,1');
  Timer? _debounce;
  Decimal? _debouncedRate = parseRatePercent('0,1');
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _rate.dispose();
    super.dispose();
  }

  Decimal? get _rateValue => parseRatePercent(_rate.text);

  String? get _rateError {
    final r = _rateValue;
    if (r == null) return 'Nhập 0–100';
    final max = (widget.cert.annualRatePercent / Decimal.fromInt(100))
        .toDecimal(scaleOnInfinitePrecision: 10);
    return r > max ? 'Vượt lãi suất của CCTG.' : null;
  }

  String? get _dateError {
    final c = widget.cert;
    if (!_date.isAfter(c.issueDate)) return 'Phải sau ngày phát hành.';
    if (!_date.isBefore(c.maturityDate)) {
      return 'Đã đến hạn: dùng tất toán đúng hạn.';
    }
    return null;
  }

  void _onRate(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _debouncedRate = _rateValue);
    });
    setState(() {});
  }

  Future<void> _pickDate() async {
    final c = widget.cert;
    final today = todayBusinessDate();
    final first = c.issueDate.add(const Duration(days: 1));
    var last = c.maturityDate.subtract(const Duration(days: 1));
    if (today.isBefore(last)) last = today;
    if (last.isBefore(first)) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(first)
          ? first
          : (_date.isAfter(last) ? last : _date),
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(last.year, last.month, last.day),
      helpText: 'Ngày tất toán',
    );
    if (picked != null) {
      setState(
        () => _date = DateTime.utc(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _confirm(EarlyRedemptionPreview p) async {
    if (_busy) return;
    final c = widget.cert;
    setState(() => _busy = true);
    final ok = await runMoneyAction<bool>(
      context,
      ref,
      reason: 'Xác nhận tất toán trước hạn ${formatMoney(p.netAmount)}',
      action: () async {
        await ref
            .read(certificateRepositoryProvider)
            .redeemEarly(c.id, date: _date, demandRate: _rateValue!);
        return true;
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok ?? false) {
      _afterChange(ref, c.id);
      Navigator.of(context).pop();
      showSnack(context, 'Đã tất toán trước hạn');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cert;
    final s = context.scheme;
    final valid =
        _dateError == null && _rateError == null && _debouncedRate != null;
    final preview = valid
        ? ref.watch(_earlyPreviewProvider((c.id, _date, _debouncedRate!)))
        : null;
    final p = preview?.value;
    final stale = _debouncedRate != _rateValue || (preview?.isLoading ?? false);
    final paid = c.totalInterestPaid ?? Decimal.zero;

    return _SheetPad(
      title: 'Tất toán trước hạn',
      children: [
        NoteCard(
          icon: LucideIcons.triangleAlert,
          text: Text(
            p == null
                ? 'Chỉ hưởng lãi không kỳ hạn; khách hàng sẽ mất phần lãi cam kết. Không thể hoàn tác.'
                : 'Chỉ hưởng lãi không kỳ hạn; khách hàng mất ${formatMoney(p.penaltyAmount)} lãi cam kết.',
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Ngày tất toán',
                    errorText: _dateError,
                    errorMaxLines: 2,
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
                  helperText: 'Tối đa ${formatPercent(c.annualRatePercent)}',
                  errorText: _rateError,
                  errorMaxLines: 2,
                ),
                onChanged: _onRate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (preview != null && preview.hasError)
          Text(
            '${preview.error}'.replaceFirst('ApiException', '').trim(),
            style: TextStyle(color: s.error),
          )
        else if (p == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Opacity(
            opacity: stale ? .5 : 1,
            child: SummaryCard(
              rows: [
                ('Gốc', formatMoney(p.principal)),
                (
                  'Lãi ${p.actualDays} ngày',
                  '+ ${formatMoney(p.interestEarned)}',
                ),
                if (paid > Decimal.zero)
                  ('Trừ lãi đã chi', '− ${formatMoney(paid)}'),
                if (p.feeEnabled)
                  (
                    'Phí tất toán sớm (${formatPercent(p.feeRate * Decimal.fromInt(100))} gốc, '
                        'trong ${p.feeWindowDays} ngày đầu)',
                    p.fee > Decimal.zero
                        ? '− ${formatMoney(p.fee)}'
                        : 'Miễn phí',
                  ),
              ],
              total: ('Thực nhận', formatMoney(p.netAmount)),
            ),
          ),
        const SizedBox(height: 16),
        _ConfirmRow(
          label: 'Xác nhận tất toán',
          danger: true,
          busy: _busy,
          onConfirm: p != null && !stale && valid ? () => _confirm(p) : null,
        ),
      ],
    );
  }
}

/// Tất toán đúng hạn: số liệu lấy từ hợp đồng (gốc + lãi cả kỳ − lãi đã chi).
class _MaturitySheet extends ConsumerStatefulWidget {
  const _MaturitySheet(this.cert);
  final Certificate cert;

  @override
  ConsumerState<_MaturitySheet> createState() => _MaturitySheetState();
}

class _MaturitySheetState extends ConsumerState<_MaturitySheet> {
  bool _busy = false;

  Future<void> _confirm(DateTime date, Decimal net) async {
    if (_busy) return;
    final c = widget.cert;
    setState(() => _busy = true);
    final ok = await runMoneyAction<bool>(
      context,
      ref,
      reason: 'Xác nhận tất toán đúng hạn ${formatMoney(net)}',
      action: () async {
        await ref
            .read(certificateRepositoryProvider)
            .redeemAtMaturity(c.id, date: date);
        return true;
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok ?? false) {
      _afterChange(ref, c.id);
      Navigator.of(context).pop();
      showSnack(context, 'Đã tất toán đúng hạn');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cert;
    final today = todayBusinessDate();
    final date = today.isAfter(c.maturityDate) ? today : c.maturityDate;
    final paid = c.totalInterestPaid ?? Decimal.zero;
    final net = c.principal + c.estimatedInterest - paid;
    return _SheetPad(
      title: 'Tất toán đúng hạn',
      children: [
        SummaryCard(
          rows: [
            ('Ngày tất toán', formatDate(date)),
            ('Gốc', formatMoney(c.principal)),
            ('Tổng lãi hợp đồng', '+ ${formatMoney(c.estimatedInterest)}'),
            if (paid > Decimal.zero)
              ('Đã chi định kỳ', '− ${formatMoney(paid)}'),
          ],
          total: ('Thực nhận', formatMoney(net)),
        ),
        const SizedBox(height: 16),
        _ConfirmRow(
          label: 'Xác nhận tất toán',
          busy: _busy,
          onConfirm: () => _confirm(date, net),
        ),
      ],
    );
  }
}

/// M09 – Chi lãi định kỳ cho một CCTG: chọn kỳ chưa chi; số tiền do hệ thống tính.
class _InterestSheet extends ConsumerStatefulWidget {
  const _InterestSheet(this.cert);
  final Certificate cert;

  @override
  ConsumerState<_InterestSheet> createState() => _InterestSheetState();
}

class _InterestSheetState extends ConsumerState<_InterestSheet> {
  int? _index;
  bool _busy = false;

  Future<void> _confirm(InterestPeriod p) async {
    if (_busy) return;
    final c = widget.cert;
    setState(() => _busy = true);
    final ok = await runMoneyAction<bool>(
      context,
      ref,
      reason: 'Xác nhận chi lãi ${formatMoney(p.amount)}',
      action: () async {
        await ref
            .read(certificateRepositoryProvider)
            .payInterest(
              c.id,
              paymentDate: todayBusinessDate(),
              periodStart: p.start,
              periodEnd: p.end,
            );
        return true;
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok ?? false) {
      _afterChange(ref, c.id);
      Navigator.of(context).pop();
      showSnack(context, 'Đã ghi nhận chi lãi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cert;
    final sch = ref.watch(interestScheduleProvider(c.id));
    return _SheetPad(
      title: 'Chi lãi định kỳ',
      children: [
        sch.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(interestScheduleProvider(c.id)),
          ),
          data: (s) {
            final open = s.periods
                .where((p) => p.status != 'Paid' && p.status != 'Blocked')
                .toList();
            if (open.isEmpty) {
              return const Text('Không còn kỳ lãi nào cần chi.');
            }
            final sel = open.firstWhere(
              (p) => p.index == _index,
              orElse: () => open.first,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioGroup<int>(
                  groupValue: sel.index,
                  onChanged: (v) => setState(() => _index = v),
                  child: Column(
                    children: [
                      for (final p in open)
                        RadioListTile<int>(
                          value: p.index,
                          title: Text(
                            'Kỳ ${p.index}/${p.total}: ${formatDate(p.start)} → ${formatDate(p.end)}',
                          ),
                          subtitle: Text(
                            '${interestPeriodStatusLabel(p.status)} · ${formatMoney(p.amount)}',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                NoteCard(
                  kind: CardKind.primaryContainer,
                  text: Text(
                    'Số tiền lãi: ${formatMoney(sel.amount)} (${sel.days} ngày × '
                    '${formatPercent(c.annualRatePercent)}/năm). Do hệ thống tính, không nhập tay.',
                  ),
                ),
                const SizedBox(height: 16),
                _ConfirmRow(
                  label: 'Xác nhận chi lãi',
                  busy: _busy,
                  onConfirm: () => _confirm(sel),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
