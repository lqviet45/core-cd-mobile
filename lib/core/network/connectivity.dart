import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` khi thiết bị có kết nối mạng (Wi‑Fi/di động/ethernet…). Chỉ phản ánh có "đường mạng" chứ không bảo đảm
/// tới được máy chủ – lỗi gọi API vẫn được xử lý riêng.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool online(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);
  yield online(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(online);
});
