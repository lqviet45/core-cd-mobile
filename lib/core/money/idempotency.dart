import 'dart:math';

final _rng = Random.secure();

/// UUID v4 cho header `Idempotency-Key`. Sinh **một lần** khi mở form và giữ nguyên khi thử lại, để lệnh gửi
/// lại (mất mạng, bấm đúp) không tạo giao dịch trùng.
String newIdempotencyKey() {
  final b = List<int>.generate(16, (_) => _rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant RFC 4122
  String hex(int from, int to) => b
      .sublist(from, to)
      .map((e) => e.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
