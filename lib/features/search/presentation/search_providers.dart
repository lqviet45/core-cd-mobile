import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/settings/app_prefs.dart';
import '../../certificates/data/certificate_dto.dart';
import '../../customers/data/customer_dto.dart';
import '../../dashboard/data/dashboard_dto.dart';

/// Kết quả tìm kiếm gộp. [failed] liệt kê nhóm bị lỗi để UI báo mà vẫn hiện các nhóm còn lại.
class SearchResults {
  const SearchResults({
    this.customers = const [],
    this.certificates = const [],
    this.transactions = const [],
    this.failed = const [],
  });
  final List<Customer> customers;
  final List<Certificate> certificates;
  final List<Transaction> transactions;
  final List<String> failed;

  bool get isEmpty =>
      customers.isEmpty && certificates.isEmpty && transactions.isEmpty;
}

/// Giống mã CIF → tra thêm giao dịch theo CIF. CIF do nhân viên nhập nên không có định dạng cố định: coi là CIF khi
/// là một từ ASCII (không dấu cách) ≥ 3 ký tự, có cả chữ lẫn số (loại số điện thoại và tên người).
bool looksLikeCif(String term) =>
    RegExp(r'^[A-Za-z0-9._-]{3,}$').hasMatch(term) &&
    RegExp('[A-Za-z]').hasMatch(term) &&
    RegExp(r'\d').hasMatch(term);

/// Tìm song song khách hàng, CCTG và (nếu giống CIF) giao dịch. Một nhóm lỗi không làm mất nhóm khác.
final searchResultsProvider = FutureProvider.autoDispose
    .family<SearchResults, String>((ref, term) async {
      final failed = <String>[];
      Future<List<T>> run<T>(String name, Future<List<T>> Function() f) =>
          f().catchError((Object _) {
            failed.add(name);
            return <T>[];
          });

      final customers = run(
        'Khách hàng',
        () async =>
            (await ref
                    .read(customerRepositoryProvider)
                    .list(search: term, pageSize: 5))
                .items,
      );
      final certs = run(
        'CCTG',
        () async =>
            (await ref
                    .read(certificateRepositoryProvider)
                    .list(search: term, pageSize: 5))
                .items,
      );
      final trxs = looksLikeCif(term)
          ? run(
              'Giao dịch',
              () async =>
                  (await ref
                          .read(transactionRepositoryProvider)
                          .list(cif: term, pageSize: 5))
                      .items,
            )
          : Future.value(<Transaction>[]);
      final r = await Future.wait<Object>([customers, certs, trxs]);
      return SearchResults(
        customers: r[0] as List<Customer>,
        certificates: r[1] as List<Certificate>,
        transactions: r[2] as List<Transaction>,
        failed: failed,
      );
    });

/// Lịch sử từ khoá tìm kiếm gần đây (lưu cục bộ, tối đa 8, xoá khi đăng xuất).
class SearchHistoryNotifier extends Notifier<List<String>> {
  static const _key = 'pref.search_history';
  static const max = 8;

  @override
  List<String> build() =>
      ref.watch(sharedPrefsProvider).getStringList(_key) ?? const [];

  Future<void> add(String term) async {
    final t = term.trim();
    if (t.length < 2) return;
    final next = [
      t,
      ...state.where((e) => e.toLowerCase() != t.toLowerCase()),
    ].take(max).toList();
    state = next;
    await ref.read(sharedPrefsProvider).setStringList(_key, next);
  }

  Future<void> clear() async {
    state = const [];
    await ref.read(sharedPrefsProvider).remove(_key);
  }
}

final searchHistoryProvider =
    NotifierProvider<SearchHistoryNotifier, List<String>>(
      SearchHistoryNotifier.new,
    );
