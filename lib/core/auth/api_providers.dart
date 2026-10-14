import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin/data/admin_repository.dart';
import '../../features/certificates/data/certificate_repository.dart';
import '../../features/customers/data/customer_repository.dart';
import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/documents/data/document_repository.dart';
import '../../features/interest/data/interest_repository.dart';
import '../../features/lots/data/lot_repository.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/reports/data/report_repository.dart';
import '../../features/transactions/data/transaction_repository.dart';
import 'providers.dart';

final adminRepositoryProvider = Provider(
  (ref) => AdminRepository(ref.watch(dioProvider)),
);
final dashboardRepositoryProvider = Provider(
  (ref) => DashboardRepository(ref.watch(dioProvider)),
);
final certificateRepositoryProvider = Provider(
  (ref) => CertificateRepository(ref.watch(dioProvider)),
);
final customerRepositoryProvider = Provider(
  (ref) => CustomerRepository(ref.watch(dioProvider)),
);
final lotRepositoryProvider = Provider(
  (ref) => LotRepository(ref.watch(dioProvider)),
);
final reportRepositoryProvider = Provider(
  (ref) => ReportRepository(ref.watch(dioProvider)),
);
final transactionRepositoryProvider = Provider(
  (ref) => TransactionRepository(ref.watch(dioProvider)),
);
final notificationRepositoryProvider = Provider(
  (ref) => NotificationRepository(ref.watch(dioProvider)),
);
final interestRepositoryProvider = Provider(
  (ref) => InterestRepository(ref.watch(dioProvider)),
);

/// Dio **trần** cho URL ngắn hạn của kho tệp: không token, không baseUrl (ghi đè trong test).
final storageDioProvider = Provider<Dio>((ref) => Dio());

final documentRepositoryProvider = Provider(
  (ref) => DocumentRepository(
    ref.watch(dioProvider),
    storage: ref.watch(storageDioProvider),
  ),
);
