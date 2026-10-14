import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/format.dart';

final _one = NumberFormat('#,##0.#', 'vi_VN');
final _two = NumberFormat('#,##0.##', 'vi_VN');
final _rate = NumberFormat('0.00', 'vi_VN');

/// Dạng gọn của thiết kế: `500 tr`, `309,8 tr`, `1,25 tỷ`; dưới 1 triệu thì đầy đủ.
String khCompact(Decimal? v) {
  if (v == null) return '—';
  final n = v.abs().toDouble();
  final sign = v < Decimal.zero ? '−' : '';
  if (n >= 1e9) return '$sign${_two.format(n / 1e9)} tỷ';
  if (n >= 1e6) return '$sign${_one.format(n / 1e6)} tr';
  return '$sign${formatMoney(v.abs())}';
}

/// `+309,8 tr` (tiền vào) / `−500.000.000 ₫` (tiền ra).
String khSignedCompact(Decimal v) => '+${khCompact(v)}';

String khSignedMoney(Decimal v, {required bool incoming}) =>
    '${incoming ? '+' : '−'}${formatMoney(v.abs())}';

/// `7.3` → `7,30%` (luôn hai chữ số thập phân như thiết kế).
String khPercent(Decimal percent) => '${_rate.format(percent.toDouble())}%';

/// `12 tháng - Trả hàng tháng` → `CCTG 12 tháng`.
String khTerm(String termName) => 'CCTG ${termName.split(' - ').first.trim()}';

String khMethodLong(String method) => switch (method) {
  'Monthly' => 'lãi hàng tháng',
  'Quarterly' => 'lãi hàng quý',
  _ => 'lãi cuối kỳ',
};

String khMethodShort(String method) => switch (method) {
  'Monthly' => 'Hàng tháng',
  'Quarterly' => 'Hàng quý',
  _ => 'Cuối kỳ',
};

String khMonthShort(DateTime d) => 'Th${d.toUtc().month}';
String khDay(DateTime d) => d.toUtc().day.toString().padLeft(2, '0');
String khMonthGroup(DateTime d) => 'Tháng ${d.toUtc().month}/${d.toUtc().year}';

/// Số ngày từ [today] tới [date] theo ngày nghiệp vụ (UTC).
int khDaysUntil(DateTime date, DateTime today) {
  DateTime day(DateTime d) =>
      DateTime.utc(d.toUtc().year, d.toUtc().month, d.toUtc().day);
  return day(date).difference(day(today)).inDays;
}

/// Tiến độ kỳ hạn 0..1 (đã trôi qua bao nhiêu phần của kỳ hạn).
double khProgress(DateTime issue, DateTime maturity, DateTime today) {
  final total = maturity.difference(issue).inDays;
  if (total <= 0) return 1;
  return (today.toUtc().difference(issue).inDays / total).clamp(0.0, 1.0);
}

String khCountdown(int days) {
  if (days < 0) return 'Đã đến hạn';
  if (days == 0) return 'Hôm nay';
  return 'Còn $days ngày';
}
