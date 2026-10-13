import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_exception.dart';
import '../ui/snack.dart';
import 'money_gate.dart';

/// Chạy một thao tác ghi tiền theo đúng quy trình: **cổng** (online · quyền · sinh trắc) → gọi API →
/// hiển thị lỗi thống nhất. Trả về kết quả, hoặc `null` nếu bị chặn/lỗi (đã báo cho người dùng).
///
/// [reason] hiện trong hộp thoại xác thực của hệ điều hành. [onFieldErrors] nhận lỗi theo trường (400).
/// Với lệnh có `Idempotency-Key`, lỗi mạng khiến kết quả không xác định nên thông báo cho phép thử lại.
Future<T?> runMoneyAction<T>(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
  required Future<T> Function() action,
  void Function(Map<String, String> fields)? onFieldErrors,
  bool idempotent = false,
}) async {
  final gate = await ref.read(moneyGateProvider).authorize(reason);
  if (!context.mounted) return null;
  if (gate != GateResult.ok) {
    showSnack(context, gateMessage(gate), error: true);
    return null;
  }
  try {
    return await action();
  } on ApiException catch (e) {
    if (!context.mounted) return null;
    if (e.status == 400 && e.fieldErrors.isNotEmpty) {
      onFieldErrors?.call(e.fieldErrors);
    }
    final suffix = e.traceId == null ? '' : ' (mã lỗi ${e.traceId})';
    final msg = e.isNetwork && idempotent
        ? 'Chưa rõ lệnh đã được gửi hay chưa. Bấm xác nhận lần nữa: hệ thống '
              'sẽ không tạo lệnh trùng.'
        : e.status == 409
        ? 'Dữ liệu vừa thay đổi (ví dụ lô vừa có giao dịch khác). Vui lòng '
              'kiểm tra lại rồi xác nhận.'
        : '${e.message}$suffix';
    showSnack(context, msg, error: true);
    return null;
  }
}
