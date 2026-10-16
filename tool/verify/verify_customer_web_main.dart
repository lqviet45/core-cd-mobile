// CHỈ ĐỂ KIỂM THỬ cục bộ trên web với backend thật (không phải mã phát hành).
// `local_auth` không chạy trên web nên thay bằng bản có/không có sinh trắc theo `?nobio=1`.
// Dùng: flutter build web --target=tool/verify/verify_customer_web_main.dart --dart-define=API_BASE_URL=...
import 'package:core_cd_mobile/core/auth/biometric.dart';
import 'package:core_cd_mobile/core/auth/providers.dart';
import 'package:core_cd_mobile/core/config/app_config.dart';
import 'package:core_cd_mobile/core/network/retry_policy.dart';
import 'package:core_cd_mobile/core/settings/app_prefs.dart';
import 'package:core_cd_mobile/features/customer_app/presentation/customer_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _WebBiometric implements BiometricAuthenticator {
  final bool _none = Uri.base.queryParameters.containsKey('nobio');

  @override
  Future<bool> isAvailable() async => !_none;

  @override
  Future<bool> authenticate(String reason) async => !_none;
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
        biometricProvider.overrideWithValue(_WebBiometric()),
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const CustomerApp(),
    ),
  );
}
