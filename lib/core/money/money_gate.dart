import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_models.dart';
import '../auth/providers.dart';
import '../network/connectivity.dart';

/// Kết quả kiểm tra trước khi cho phép một thao tác ghi tiền.
enum GateResult {
  ok,

  /// Mất mạng: offline chỉ đọc, không xếp hàng lệnh ghi.
  offline,

  /// Vai trò thấp hơn Operator.
  forbidden,

  /// Thiết bị không có khoá màn hình/sinh trắc nên không thể xác thực.
  noDeviceLock,

  /// Người dùng huỷ hoặc xác thực thất bại.
  denied,
}

String gateMessage(GateResult r) => switch (r) {
  GateResult.ok => '',
  GateResult.offline => 'Đang offline. Thao tác ghi cần kết nối mạng, vui lòng thử lại khi có mạng.',
  GateResult.forbidden => 'Bạn không có quyền thực hiện thao tác này.',
  GateResult.noDeviceLock =>
    'Thiết bị chưa đặt khoá màn hình hoặc sinh trắc nên không thể xác thực. '
        'Hãy đặt khoá màn hình rồi thử lại.',
  GateResult.denied => 'Xác thực không thành công. Lệnh chưa được gửi.',
};

/// Cổng bắt buộc **ngay trước** mọi thao tác ghi tiền: đang online → đủ quyền → xác thực sinh trắc/mã thiết bị.
/// Không lưu kết quả xác thực để dùng lại: mỗi thao tác phải gọi [authorize] một lần.
class MoneyGate {
  MoneyGate(this._ref);
  final Ref _ref;

  /// Có quyền ghi (Operator trở lên) – dùng để ẩn/hiện nút.
  bool get canWrite {
    final auth = _ref.read(authControllerProvider);
    return auth is AuthSignedIn && auth.user.role.atLeast(Role.operator);
  }

  Future<GateResult> authorize(String reason) async {
    if (!canWrite) return GateResult.forbidden;
    final online = _ref.read(isOnlineProvider).value ?? true;
    if (!online) return GateResult.offline;
    final bio = _ref.read(biometricProvider);
    if (!await bio.isAvailable()) return GateResult.noDeviceLock;
    return await bio.authenticate(reason) ? GateResult.ok : GateResult.denied;
  }
}

final moneyGateProvider = Provider<MoneyGate>(MoneyGate.new);

/// Người dùng hiện tại có quyền ghi không (để ẩn nút ở Viewer).
final canWriteProvider = Provider<bool>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is AuthSignedIn && auth.user.role.atLeast(Role.operator);
});
