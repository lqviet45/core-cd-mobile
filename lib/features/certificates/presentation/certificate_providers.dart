import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/models/paged.dart';
import '../../../core/paging/paged_notifier.dart';
import '../data/certificate_dto.dart';

/// Bộ lọc danh sách CCTG: trạng thái (rỗng = tất cả) + từ khoá.
class CertificateQuery {
  const CertificateQuery({this.status = '', this.search = ''});
  final String status;
  final String search;

  CertificateQuery copyWith({String? status, String? search}) =>
      CertificateQuery(
        status: status ?? this.status,
        search: search ?? this.search,
      );
}

class CertificateQueryNotifier extends Notifier<CertificateQuery> {
  @override
  CertificateQuery build() => const CertificateQuery();

  // ignore: use_setters_to_change_properties
  void set(CertificateQuery q) => state = q;
}

final certificateQueryProvider =
    NotifierProvider<CertificateQueryNotifier, CertificateQuery>(
      CertificateQueryNotifier.new,
    );

class CertificatesNotifier extends PagedNotifier<Certificate> {
  @override
  PagedState<Certificate> build() {
    ref.watch(
      certificateQueryProvider,
    ); // đổi bộ lọc → dựng lại và tải từ trang 1
    return super.build();
  }

  @override
  Future<Paged<Certificate>> fetch(int page) {
    final q = ref.read(certificateQueryProvider);
    return ref
        .read(certificateRepositoryProvider)
        .list(page: page, status: q.status, search: q.search);
  }
}

final certificatesProvider =
    NotifierProvider<CertificatesNotifier, PagedState<Certificate>>(
      CertificatesNotifier.new,
    );

final certificateProvider = FutureProvider.autoDispose
    .family<Certificate, String>(
      (ref, id) => ref.watch(certificateRepositoryProvider).get(id),
    );

final interestScheduleProvider = FutureProvider.autoDispose
    .family<InterestSchedule, String>(
      (ref, id) => ref.watch(certificateRepositoryProvider).schedule(id),
    );

/// CCTG của một khách hàng (tối đa 100 gần nhất – đủ cho màn chi tiết khách hàng).
final customerCertificatesProvider = FutureProvider.autoDispose
    .family<Paged<Certificate>, String>(
      (ref, customerId) => ref
          .watch(certificateRepositoryProvider)
          .list(pageSize: 100, customerId: customerId),
    );
