import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/api_providers.dart';
import '../../reports/data/report_dto.dart';
import '../data/dashboard_dto.dart';

final dashboardProvider = FutureProvider.autoDispose<Dashboard>(
  (ref) => ref.watch(dashboardRepositoryProvider).summary(),
);

/// Lịch đáo hạn trong 30 ngày tới (dùng cho tổng quan và màn "Lịch đáo hạn").
final upcomingProvider = FutureProvider.autoDispose<UpcomingReport>(
  (ref) => ref.watch(reportRepositoryProvider).upcoming(),
);

final unreadCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(notificationRepositoryProvider).unreadCount(),
);
