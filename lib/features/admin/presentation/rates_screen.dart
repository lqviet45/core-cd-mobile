import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/models/paged.dart';
import '../../../core/money/money_action.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/ui/paged_list.dart';
import '../../../core/ui/snack.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/labels.dart';
import '../data/admin_dto.dart';
import 'admin_common.dart';

/// `true` = đang áp dụng, `false` = đã ngừng, `null` = tất cả.
class RateFilterNotifier extends Notifier<bool?> {
  @override
  bool? build() => true;

  // ignore: use_setters_to_change_properties
  void set(bool? v) => state = v;
}

final rateFilterProvider = NotifierProvider<RateFilterNotifier, bool?>(
  RateFilterNotifier.new,
);

class RatesNotifier extends PagedNotifier<RatePolicy> {
  @override
  PagedState<RatePolicy> build() {
    ref.watch(rateFilterProvider);
    return super.build();
  }

  @override
  Future<Paged<RatePolicy>> fetch(int page) => ref
      .read(adminRepositoryProvider)
      .ratePolicies(page: page, isActive: ref.read(rateFilterProvider));
}

final ratesProvider = NotifierProvider<RatesNotifier, PagedState<RatePolicy>>(
  RatesNotifier.new,
);

/// Lãi suất nhập theo % (chấp nhận dấu phẩy hoặc chấm). Hợp lệ khi 0 < lãi < 100.
Decimal? parseRatePercent(String text) {
  final d = Decimal.tryParse(text.trim().replaceAll(',', '.'));
  if (d == null || d <= Decimal.zero || d >= Decimal.fromInt(100)) return null;
  return d;
}

/// M-Chính sách lãi suất. Mọi vai trò xem được; chỉ Admin thêm/sửa/ngừng áp dụng.
class RatesScreen extends ConsumerWidget {
  const RatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ratesProvider);
    final filter = ref.watch(rateFilterProvider);
    final notifier = ref.read(ratesProvider.notifier);
    final admin = ref.watch(isAdminProvider);

    Future<void> open([RatePolicy? p]) async {
      final changed = await showAdminSheet<bool>(
        context,
        RateFormSheet(policy: p),
      );
      if (changed ?? false) await notifier.refresh();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chính sách lãi suất'),
        actions: [
          if (admin)
            IconBtn(
              icon: LucideIcons.plus,
              label: 'Thêm chính sách',
              onPressed: open,
            ),
        ],
      ),
      body: Column(
        children: [
          FilterChipsRow<bool?>(
            options: const [
              (true, 'Đang áp dụng'),
              (false, 'Đã ngừng'),
              (null, 'Tất cả'),
            ],
            value: filter,
            onChanged: (v) => ref.read(rateFilterProvider.notifier).set(v),
          ),
          Expanded(
            child: PagedListView<RatePolicy>(
              state: state,
              onRefresh: notifier.refresh,
              onLoadMore: notifier.loadMore,
              emptyTitle: 'Chưa có chính sách lãi suất',
              separatorHeight: 8,
              itemBuilder: (context, p) => ListGroup(
                children: [
                  ListRow(
                    lead: const Lead(square: true, icon: LucideIcons.percent),
                    title:
                        '${p.termName} · ${paymentMethodLabel(p.paymentMethod).toLowerCase()}',
                    subtitle:
                        'Từ ${formatDate(p.effectiveFrom)}'
                        '${p.effectiveTo == null ? '' : ' đến ${formatDate(p.effectiveTo)}'}'
                        ' · ${p.termDays} ngày',
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${formatPercent(p.annualRatePercent)}/năm',
                          style: context.text.titleMedium,
                        ),
                        if (!p.isActive)
                          const StatusChip((
                            label: 'Đã ngừng',
                            tone: Tone.neutral,
                          )),
                      ],
                    ),
                    chevron: admin,
                    onTap: admin ? () => open(p) : null,
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

/// Thêm ([policy] = null) hoặc sửa chính sách lãi suất. Chỉ Admin; thao tác ghi cần xác thực sinh trắc.
class RateFormSheet extends ConsumerStatefulWidget {
  const RateFormSheet({super.key, this.policy});
  final RatePolicy? policy;

  @override
  ConsumerState<RateFormSheet> createState() => _RateFormSheetState();
}

class _RateFormSheetState extends ConsumerState<RateFormSheet> {
  late final _term = TextEditingController(text: widget.policy?.termName);
  late final _days = TextEditingController(
    text: widget.policy?.termDays.toString(),
  );
  late final _rate = TextEditingController(
    text: widget.policy?.annualRatePercent.toString().replaceAll('.', ','),
  );
  late final _desc = TextEditingController(text: widget.policy?.description);
  late String _method = widget.policy?.paymentMethod ?? 'AtMaturity';
  late DateTime? _from = widget.policy?.effectiveFrom.toUtc();
  late DateTime? _to = widget.policy?.effectiveTo?.toUtc();
  Map<String, String> _errors = {};
  bool _busy = false;

  bool get _isNew => widget.policy == null;

  @override
  void dispose() {
    _term.dispose();
    _days.dispose();
    _rate.dispose();
    _desc.dispose();
    super.dispose();
  }

  Map<String, String> _validate() {
    final e = <String, String>{};
    if (_term.text.trim().isEmpty) {
      e['termName'] = 'Tên kỳ hạn không được trống.';
    }
    final d = int.tryParse(_days.text.trim());
    if (d == null || d <= 0) e['termDays'] = 'Số ngày phải lớn hơn 0.';
    if (parseRatePercent(_rate.text) == null) {
      e['annualRate'] = 'Lãi suất phải lớn hơn 0% và nhỏ hơn 100%.';
    }
    if (_from == null) e['effectiveFrom'] = 'Chọn ngày bắt đầu hiệu lực.';
    if (_from != null && _to != null && _to!.isBefore(_from!)) {
      e['effectiveTo'] = 'Ngày kết thúc phải sau ngày bắt đầu.';
    }
    return e;
  }

  Future<void> _pickDate({required bool from}) async {
    final init = (from ? _from : _to) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      final utc = DateTime.utc(d.year, d.month, d.day);
      if (from) {
        _from = utc;
        _errors = {..._errors}..remove('effectiveFrom');
      } else {
        _to = utc;
      }
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final local = _validate();
    setState(() => _errors = local);
    if (local.isNotEmpty) return;
    setState(() => _busy = true);
    final repo = ref.read(adminRepositoryProvider);
    final ok = await runMoneyAction<bool>(
      context,
      ref,
      reason: 'Xác thực để lưu chính sách lãi suất',
      onFieldErrors: (f) => setState(() => _errors = f),
      action: () async {
        final rate = parseRatePercent(_rate.text)!;
        final days = int.parse(_days.text.trim());
        if (_isNew) {
          await repo.createRate(
            termName: _term.text,
            termDays: days,
            annualRatePercent: rate,
            paymentMethod: _method,
            effectiveFrom: _from!,
            effectiveTo: _to,
            description: _desc.text,
          );
        } else {
          await repo.updateRate(
            id: widget.policy!.id,
            termName: _term.text,
            termDays: days,
            annualRatePercent: rate,
            paymentMethod: _method,
            effectiveFrom: _from!,
            effectiveTo: _to,
            description: _desc.text,
          );
        }
        return true;
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok ?? false) {
      showSnack(context, 'Đã lưu chính sách lãi suất');
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deactivate() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ngừng áp dụng chính sách?'),
        content: const Text(
          'Các CCTG đã phát hành giữ nguyên lãi suất đã chốt. Chính sách này sẽ không còn được dùng cho CCTG mới.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Ngừng áp dụng'),
          ),
        ],
      ),
    );
    if (!(sure ?? false) || !mounted) return;
    setState(() => _busy = true);
    final ok = await runMoneyAction<bool>(
      context,
      ref,
      reason: 'Xác thực để ngừng chính sách lãi suất',
      action: () async {
        await ref
            .read(adminRepositoryProvider)
            .deactivateRate(widget.policy!.id);
        return true;
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok ?? false) {
      showSnack(context, 'Đã ngừng áp dụng');
      Navigator.of(context).pop(true);
    }
  }

  Widget _field(
    String key,
    TextEditingController c,
    String label, {
    TextInputType? type,
    String? suffix,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        errorText: _errors[key],
        errorMaxLines: 3,
      ),
      onChanged: (_) {
        if (_errors.containsKey(key)) {
          setState(() => _errors = {..._errors}..remove(key));
        }
      },
    ),
  );

  Widget _dateTile(
    String key,
    String label,
    DateTime? value, {
    required bool from,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: InkWell(
      onTap: () => _pickDate(from: from),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: _errors[key],
          suffixIcon: !from && value != null
              ? IconButton(
                  tooltip: 'Bỏ ngày kết thúc',
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => setState(() => _to = null),
                )
              : const Icon(LucideIcons.calendar, size: 18),
        ),
        child: Text(value == null ? 'Chọn ngày' : formatDate(value)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _isNew ? 'Thêm chính sách lãi suất' : 'Sửa chính sách lãi suất',
        style: context.text.titleLarge,
      ),
      const SizedBox(height: 16),
      _field('termName', _term, 'Tên kỳ hạn (vd 12 tháng)'),
      _field('termDays', _days, 'Số ngày kỳ hạn', type: TextInputType.number),
      _field(
        'annualRate',
        _rate,
        'Lãi suất năm',
        type: const TextInputType.numberWithOptions(decimal: true),
        suffix: '%',
      ),
      Text('Hình thức trả lãi', style: context.text.labelLarge),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          for (final m in const ['AtMaturity', 'Monthly', 'Quarterly'])
            ChoiceChip(
              label: Text(paymentMethodLabel(m)),
              selected: _method == m,
              onSelected: (_) => setState(() => _method = m),
            ),
        ],
      ),
      const SizedBox(height: 16),
      _dateTile('effectiveFrom', 'Hiệu lực từ', _from, from: true),
      _dateTile(
        'effectiveTo',
        'Hiệu lực đến (không bắt buộc)',
        _to,
        from: false,
      ),
      _field('description', _desc, 'Ghi chú (không bắt buộc)'),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Đang lưu…' : 'Lưu'),
      ),
      if (!_isNew && widget.policy!.isActive) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: context.scheme.error,
          ),
          onPressed: _busy ? null : _deactivate,
          icon: const Icon(LucideIcons.ban, size: 18),
          label: const Text('Ngừng áp dụng'),
        ),
      ],
    ],
  );
}
