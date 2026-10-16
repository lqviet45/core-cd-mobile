import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'customer_router.dart';
import 'kh_theme.dart';

/// Gốc của app khách hàng (điểm vào: `lib/main_customer.dart`). Giao diện sáng/tối theo hệ thống (K02/K09).
class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Chứng chỉ tiền gửi',
    debugShowCheckedModeBanner: false,
    theme: buildKhTheme(Brightness.light),
    darkTheme: buildKhTheme(Brightness.dark),
    locale: const Locale('vi', 'VN'),
    supportedLocales: const [Locale('vi', 'VN')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: ref.watch(customerRouterProvider),
  );
}
