import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

final _vnInt = NumberFormat.decimalPattern('vi_VN');

/// `1234567` → `1.234.567 ₫`. Làm tròn về đồng (VND không có đơn vị nhỏ hơn).
String formatMoney(Decimal? value) {
  if (value == null) return '—';
  final rounded = value.round();
  return '${_vnInt.format(BigInt.parse(rounded.toString()).toInt())} ₫';
}

/// Dạng gọn cho số lớn: `1.250.000.000` → `1,25 tỷ`, `3.400.000` → `3,4 tr`.
String formatCompact(Decimal? value) {
  if (value == null) return '—';
  final abs = value.abs().toDouble();
  final n = value.toDouble();
  String f(double v) => NumberFormat('#,##0.##', 'vi_VN').format(v);
  if (abs >= 1e12) return '${f(n / 1e12)} nghìn tỷ';
  if (abs >= 1e9) return '${f(n / 1e9)} tỷ';
  if (abs >= 1e6) return '${f(n / 1e6)} tr';
  return _vnInt.format(n.round());
}

/// `7.5` → `7,5%`. Nhận phần trăm (không phải tỷ lệ).
String formatPercent(Decimal? percent, {int maxDigits = 2}) {
  if (percent == null) return '—';
  final f = NumberFormat('#,##0.${'#' * maxDigits}', 'vi_VN');
  return '${f.format(percent.toDouble())}%';
}

String formatInt(num? value) => value == null ? '—' : _vnInt.format(value);

/// Ngày nghiệp vụ lưu dạng UTC 00:00 → dùng thành phần UTC để không lệch ngày theo múi giờ máy.
String formatDate(DateTime? d) {
  if (d == null) return '—';
  final u = d.toUtc();
  return '${u.day.toString().padLeft(2, '0')}/${u.month.toString().padLeft(2, '0')}/${u.year}';
}

/// Thời điểm thực (đăng nhập, tạo bản ghi) → giờ địa phương của máy.
String formatDateTime(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(l.hour)}:${two(l.minute)} ${two(l.day)}/${two(l.month)}/${l.year}';
}

/// Dạng "còn N ngày" / "quá N ngày" so với [today] (cùng quy ước UTC của ngày nghiệp vụ).
String formatDaysFrom(DateTime date, DateTime today) {
  final days =
      DateTime.utc(date.toUtc().year, date.toUtc().month, date.toUtc().day)
          .difference(
            DateTime.utc(
              today.toUtc().year,
              today.toUtc().month,
              today.toUtc().day,
            ),
          )
          .inDays;
  if (days == 0) return 'hôm nay';
  return days > 0 ? 'còn $days ngày' : 'quá ${-days} ngày';
}

/// `yyyy-MM-dd` theo thành phần UTC (ngày nghiệp vụ) để gửi lên API.
String formatIsoDate(DateTime d) {
  final u = d.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)}';
}

/// Ngày hôm nay (lịch của máy) dưới dạng ngày nghiệp vụ UTC 00:00.
DateTime todayBusinessDate([DateTime? now]) {
  final n = now ?? DateTime.now();
  return DateTime.utc(n.year, n.month, n.day);
}
