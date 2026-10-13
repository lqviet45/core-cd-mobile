import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Định dạng số nguyên VND khi gõ: `1234567` → `1.234.567`.
class VndInputFormatter extends TextInputFormatter {
  const VndInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return TextEditingValue.empty;
    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final text = groupThousands(trimmed);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String groupThousands(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write('.');
    b.write(digits[i]);
  }
  return b.toString();
}

/// Đọc lại số tiền từ chuỗi đã định dạng (`null` nếu rỗng).
Decimal? parseVnd(String text) {
  final digits = text.replaceAll(RegExp(r'\D'), '');
  return digits.isEmpty ? null : Decimal.parse(digits);
}

/// Ô nhập số tiền VND (số nguyên), có hậu tố ₫.
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.errorText,
    this.helperText,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<Decimal?>? onChanged;
  final String? errorText;
  final String? helperText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    autofocus: autofocus,
    keyboardType: TextInputType.number,
    inputFormatters: const [VndInputFormatter()],
    style: Theme.of(context).textTheme.headlineSmall,
    decoration: InputDecoration(
      labelText: label,
      suffixText: '₫',
      errorText: errorText,
      helperText: helperText,
      helperMaxLines: 2,
      errorMaxLines: 3,
    ),
    onChanged: onChanged == null ? null : (v) => onChanged!(parseVnd(v)),
  );
}

/// Số JSON gửi lên API: số nguyên khi không có phần thập phân (VND ≤ 2^53 nên chính xác).
num jsonNum(Decimal d) =>
    d.scale == 0 || d == d.truncate() ? d.toBigInt().toInt() : d.toDouble();
