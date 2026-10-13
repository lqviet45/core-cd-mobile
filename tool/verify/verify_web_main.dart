// CHỈ ĐỂ KIỂM THỬ cục bộ trên web với backend thật (không phải mã phát hành).
// Trên web `local_auth` không dùng được nên cổng sinh trắc luôn từ chối; ở đây thay bằng bản luôn đồng ý để
// duyệt được các luồng ghi tiền. Dùng: flutter build web --target=tool/verify/verify_web_main.dart --dart-define=API_BASE_URL=...
import 'package:core_cd_mobile/app.dart';
import 'package:core_cd_mobile/core/auth/biometric.dart';
import 'package:core_cd_mobile/core/auth/providers.dart';
import 'package:core_cd_mobile/core/config/app_config.dart';
import 'package:core_cd_mobile/core/network/retry_policy.dart';
import 'package:core_cd_mobile/core/settings/app_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AlwaysYes implements BiometricAuthenticator {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate(String reason) async => true;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN');
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      retry: noAutoRetry,
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.fromEnvironment()),
        biometricProvider.overrideWithValue(_AlwaysYes()),
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const CoreCdApp(),
    ),
  );
}
