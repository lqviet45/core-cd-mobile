import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/providers.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/auth/token_store.dart';
import '../../../core/models/paged.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/paging/paged_notifier.dart';
import '../data/customer_app_dto.dart';
import '../data/customer_app_repository.dart';
import '../data/customer_auth_api.dart';

// Hạ tầng riêng của app khách hàng: token store khoá riêng, API xác thực riêng, KHÔNG có cache đọc và KHÔNG có push.
// Dùng lại SessionManager/AuthInterceptor của lõi (single-flight refresh, xoay vòng token).

final custTokenStoreProvider = Provider<TokenStore>(
  (ref) => SecureTokenStore(key: 'core_cd_customer.refresh_token'),
);

final custAuthApiProvider = Provider<CustomerAuthApi>(
  (ref) => CustomerAuthApi(
    createBareDio(ref.watch(appConfigProvider)),
    deviceName: ref.watch(deviceNameProvider),
  ),
);

final custSessionProvider = Provider<SessionManager>((ref) {
  final manager = SessionManager(
    store: ref.watch(custTokenStoreProvider),
    api: ref.watch(custAuthApiProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final custRepositoryProvider = Provider<CustomerAppRepository>(
  (ref) => CustomerAppRepository(
    createAuthedDio(
      ref.watch(appConfigProvider),
      ref.watch(custSessionProvider),
    ),
  ),
);

/// Trạng thái đăng nhập (dùng lại các lớp của [AuthState]).
class CustomerAuthController extends Notifier<AuthState> {
  StreamSubscription<SessionEvent>? _sub;

  @override
  AuthState build() {
    final session = ref.watch(custSessionProvider);
    _sub = session.events.listen((e) {
      state = switch (e) {
        SignedIn(:final user) => AuthSignedIn(user),
        SignedOut(:final expired) => AuthSignedOut(expired: expired),
      };
    });
    ref.onDispose(() => _sub?.cancel());
    unawaited(_restore(session));
    return const AuthRestoring();
  }

  Future<void> _restore(SessionManager session) async {
    try {
      final user = await session.restore();
      if (state is AuthRestoring || state is AuthOffline) {
        state = user == null
            ? const AuthSignedOut()
            : AuthSignedIn(user, restored: true);
      }
    } on Object {
      state = const AuthOffline();
    }
  }

  Future<void> retryRestore() async {
    state = const AuthRestoring();
    await _restore(ref.read(custSessionProvider));
  }

  Future<OtpRequested> requestOtp(String phone) =>
      ref.read(custAuthApiProvider).requestOtp(phone);

  Future<void> verifyOtp(String phone, String code) async {
    final tokens = await ref.read(custAuthApiProvider).verifyOtp(phone, code);
    await ref.read(custSessionProvider).signIn(tokens);
  }

  Future<void> logout() => ref.read(custSessionProvider).logout();
}

final custAuthControllerProvider =
    NotifierProvider<CustomerAuthController, AuthState>(
      CustomerAuthController.new,
    );

/// Hồ sơ và tổng quan: tải lại khi người dùng kéo để làm mới (`ref.invalidate`).
final custProfileProvider = FutureProvider<CustomerProfile>(
  (ref) => ref.watch(custRepositoryProvider).me(),
);

final custSummaryProvider = FutureProvider<CustomerSummary>(
  (ref) => ref.watch(custRepositoryProvider).summary(),
);

/// Bộ lọc danh sách CCTG: `Holding` (đang giữ) hoặc `Closed` (đã đóng).
class CertScopeNotifier extends Notifier<String> {
  @override
  String build() => 'Holding';

  // ignore: use_setters_to_change_properties
  void set(String v) => state = v;
}

final custCertScopeProvider = NotifierProvider<CertScopeNotifier, String>(
  CertScopeNotifier.new,
);

class CustCertificatesNotifier extends PagedNotifier<CustCertificate> {
  @override
  Future<Paged<CustCertificate>> fetch(int page) => ref
      .read(custRepositoryProvider)
      .certificates(scope: ref.watch(custCertScopeProvider), page: page);
}

final custCertificatesProvider =
    NotifierProvider<CustCertificatesNotifier, PagedState<CustCertificate>>(
      CustCertificatesNotifier.new,
    );

class CustTransactionsNotifier extends PagedNotifier<CustTransaction> {
  @override
  Future<Paged<CustTransaction>> fetch(int page) =>
      ref.read(custRepositoryProvider).transactions(page: page);
}

final custTransactionsProvider =
    NotifierProvider<CustTransactionsNotifier, PagedState<CustTransaction>>(
      CustTransactionsNotifier.new,
    );

final custCertificateProvider = FutureProvider.family<CustCertificate, String>(
  (ref, id) => ref.watch(custRepositoryProvider).certificate(id),
);

final custScheduleProvider =
    FutureProvider.family<CustInterestSchedule, String>(
      (ref, id) => ref.watch(custRepositoryProvider).interestSchedule(id),
    );

final custTransactionProvider = FutureProvider.family<CustTransaction, String>(
  (ref, id) => ref.watch(custRepositoryProvider).transaction(id),
);

/// Tài liệu của một đối tượng: khoá `(ownerType, ownerId)` với `ownerType` ∈ `certificates | transactions`.
final custDocumentsProvider =
    FutureProvider.family<List<CustDocument>, ({String type, String id})>(
      (ref, k) => ref.watch(custRepositoryProvider).documents(k.type, k.id),
    );

/// Mở tài liệu bằng ứng dụng hệ thống. Tách giao diện để test không cần plugin.
abstract interface class CustDocumentOpener {
  Future<bool> open(String url);
}

/// Thông báo lỗi thân thiện cho màn đăng nhập.
String loginErrorText(Object e) {
  if (e is ApiException) return otpErrorMessage(e);
  return 'Có lỗi xảy ra. Vui lòng thử lại.';
}
