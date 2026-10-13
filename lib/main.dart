import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/auth/providers.dart';
import 'core/config/app_config.dart';
import 'core/network/retry_policy.dart';
import 'core/settings/app_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN');

  final config = AppConfig.fromEnvironment()..validate();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      retry: noAutoRetry,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const CoreCdApp(),
    ),
  );
}
