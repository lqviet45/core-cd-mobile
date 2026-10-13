/// Chữ cái đầu của hai từ cuối của họ tên: "Trần Quốc Bảo" → "QB".
String initialsOf(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final last = parts.length >= 2 ? parts.sublist(parts.length - 2) : parts;
  return last.map((p) => p[0]).join().toUpperCase();
}

/// Tên gọi (từ cuối) dùng trong lời chào: "Trần Quốc Bảo" → "Bảo".
String givenNameOf(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  return parts.isEmpty ? '' : parts.last;
}

const _weekdays = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];

/// "Thứ Hai, 12/10/2026" (ngày nghiệp vụ UTC).
String weekdayDateOf(DateTime d) {
  final u = d.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${_weekdays[u.weekday - 1]}, ${two(u.day)}/${two(u.month)}/${u.year}';
}
