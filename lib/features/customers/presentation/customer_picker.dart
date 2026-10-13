import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/labels.dart';
import '../../../core/utils/text.dart';
import '../data/customer_dto.dart';

/// Kết quả tìm khách hàng đang hoạt động (≥ 2 ký tự).
final customerSearchProvider = FutureProvider.autoDispose
    .family<List<Customer>, String>((ref, term) async {
      final page = await ref
          .watch(customerRepositoryProvider)
          .list(search: term, pageSize: 6, isActive: true);
      return page.items;
    });

/// Chọn một khách hàng: hiện thẻ khách đã chọn (có nút "Đổi") hoặc ô tìm kiếm + danh sách gợi ý.
class CustomerPicker extends ConsumerStatefulWidget {
  const CustomerPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Customer? value;
  final ValueChanged<Customer?> onChanged;

  @override
  ConsumerState<CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends ConsumerState<CustomerPicker> {
  Timer? _debounce;
  String _term = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onText(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => setState(() => _term = v.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.value;
    final s = context.scheme;
    if (c != null) {
      return AppCard(
        kind: CardKind.outlined,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            if (c.isBusiness)
              const Lead(square: true, icon: LucideIcons.building2)
            else
              Lead(text: initialsOf(c.fullName)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.fullName, style: context.text.titleMedium),
                  Text(
                    '${c.cif} · ${customerTypeLabel(c.customerType)}',
                    style: context.text.bodySmall?.copyWith(
                      color: s.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _term = '');
                widget.onChanged(null);
              },
              child: const Text('Đổi'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SearchField(
          hint: 'Tên, CIF hoặc CCCD/MST (≥ 2 ký tự)',
          onChanged: _onText,
        ),
        if (_term.length >= 2)
          ref
              .watch(customerSearchProvider(_term))
              .when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Không tìm được khách hàng.',
                    style: TextStyle(color: s.error),
                  ),
                ),
                data: (list) => list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Không tìm thấy khách hàng.'),
                      )
                    : ListGroup(
                        children: [
                          for (final x in list)
                            ListRow(
                              lead: x.isBusiness
                                  ? const Lead(
                                      square: true,
                                      icon: LucideIcons.building2,
                                    )
                                  : Lead(text: initialsOf(x.fullName)),
                              title: x.fullName,
                              subtitle: '${x.cif} · ${x.phone}',
                              onTap: () => widget.onChanged(x),
                            ),
                        ],
                      ),
              ),
      ],
    );
  }
}
