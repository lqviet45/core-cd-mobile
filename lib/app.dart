import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push_registrar.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_prefs.dart';
import 'core/ui/theme.dart';

class CoreCdApp extends ConsumerWidget {
  const CoreCdApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Đăng ký push theo trạng thái đăng nhập; chạm vào push → điều hướng tới màn hình tương ứng.
    ref
      ..watch(pushLifecycleProvider)
      ..listen(pushRouteProvider, (_, route) {
        if (route == null) return;
        ref.read(routerProvider).go(route);
        ref.read(pushRouteProvider.notifier).set(null);
      });
    return MaterialApp.router(
      title: 'Core CD',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(appPrefsProvider.select((p) => p.themeMode)),
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
