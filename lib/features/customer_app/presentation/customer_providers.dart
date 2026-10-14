import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/providers.dart';
import '../../../core/auth/session_manager.dart';
import '../../../core/auth/token_store.dart';
import '../../../core/models/paged.dart';
import '../../../core/network/api_client.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/settings/app_prefs.dart';
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

// ── sinh trắc ───────────────────────────────────────────────────────
/// "Mở khoá bằng vân tay / Face ID": khi bật, mở app lại không tự vào mà phải xác thực sinh trắc/khoá thiết bị.
/// `null` = người dùng chưa chọn (lần đăng nhập đầu sẽ tự bật nếu thiết bị hỗ trợ).
class CustBiometricPref extends Notifier<bool?> {
  static const _key = 'kh.biometric_unlock';

  @override
  bool? build() => ref.watch(sharedPrefsProvider).getBool(_key);

  Future<void> set(bool v) async {
    state = v;
    await ref.read(sharedPrefsProvider).setBool(_key, v);
  }
}

final custBiometricPrefProvider = NotifierProvider<CustBiometricPref, bool?>(
  CustBiometricPref.new,
);

/// Thiết bị có sinh trắc/khoá màn hình để dùng không.
final custBiometricAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricProvider).isAvailable(),
);

/// true = có phiên đã lưu đang chờ xác thực sinh trắc (màn đăng nhập hiện nút "Đăng nhập bằng vân tay / Face ID").
class CustBiometricReady extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void set(bool v) => state = v;
}

final custBiometricReadyProvider = NotifierProvider<CustBiometricReady, bool>(
  CustBiometricReady.new,
);

/// true = khách còn dùng mật khẩu tạm và phải đổi trước khi xem dữ liệu.
class CustMustChange extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void set(bool v) => state = v;
}

final custMustChangeProvider = NotifierProvider<CustMustChange, bool>(
  CustMustChange.new,
);

// ── đăng nhập ───────────────────────────────────────────────────────
/// Trạng thái đăng nhập (dùng lại các lớp của `AuthState`).
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
    unawaited(_start());
    return const AuthRestoring();
  }

  /// Mở app: có phiên đã lưu thì (nếu bật sinh trắc) chờ xác thực, ngược lại khôi phục luôn.
  Future<void> _start() async {
    try {
      final stored = await ref.read(custTokenStoreProvider).readRefreshToken();
      if (stored == null) {
        state = const AuthSignedOut();
        return;
      }
      final bio = ref.read(custBiometricPrefProvider) ?? false;
      if (bio && await ref.read(biometricProvider).isAvailable()) {
        ref.read(custBiometricReadyProvider.notifier).set(true);
        state = const AuthSignedOut();
        return;
      }
      await _restore();
    } on Object {
      state = const AuthOffline();
    }
  }

  Future<void> _restore() async {
    final session = ref.read(custSessionProvider);
    try {
      final user = await session.restore();
      ref
          .read(custMustChangeProvider.notifier)
          .set(ref.read(custAuthApiProvider).mustChangePassword);
      if (state is AuthRestoring ||
          state is AuthOffline ||
          state is AuthSignedOut) {
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
    await _restore();
  }

  /// Đăng nhập bằng SĐT/CIF + mật khẩu. Lần đầu (chưa từng chọn) tự bật mở khoá sinh trắc nếu thiết bị hỗ trợ.
  Future<void> login(String identifier, String password) async {
    await ref.read(custSessionProvider).login(identifier, password);
    ref
        .read(custMustChangeProvider.notifier)
        .set(ref.read(custAuthApiProvider).mustChangePassword);
    ref.read(custBiometricReadyProvider.notifier).set(false);
    if (ref.read(custBiometricPrefProvider) == null &&
        await ref.read(biometricProvider).isAvailable()) {
      await ref.read(custBiometricPrefProvider.notifier).set(true);
    }
  }

  /// Mở phiên đã lưu sau khi xác thực sinh trắc/khoá thiết bị thành công. Trả `false` nếu bị từ chối.
  Future<bool> unlockWithBiometric() async {
    final ok = await ref
        .read(biometricProvider)
        .authenticate('Xác thực để mở ứng dụng');
    if (!ok) return false;
    ref.read(custBiometricReadyProvider.notifier).set(false);
    state = const AuthRestoring();
    await _restore();
    return state is AuthSignedIn;
  }

  /// Đổi mật khẩu (lần đầu hoặc chủ động). Máy chủ trả phiên mới nên khách không bị đăng xuất.
  Future<void> changePassword(String current, String next) async {
    final session = ref.read(custSessionProvider);
    final api = ref.read(custAuthApiProvider);
    final tokens = await api.changePassword(
      accessToken: session.accessToken ?? '',
      currentPassword: current,
      newPassword: next,
    );
    await session.signIn(tokens);
    ref.read(custMustChangeProvider.notifier).set(api.mustChangePassword);
  }

  Future<void> logout() async {
    ref.read(custBiometricReadyProvider.notifier).set(false);
    ref.read(custMustChangeProvider.notifier).set(false);
    await ref.read(custSessionProvider).logout();
  }
}

final custAuthControllerProvider =
    NotifierProvider<CustomerAuthController, AuthState>(
      CustomerAuthController.new,
    );

// ── dữ liệu ─────────────────────────────────────────────────────────
final custProfileProvider = FutureProvider<CustomerProfile>(
  (ref) => ref.watch(custRepositoryProvider).me(),
);

final custSummaryProvider = FutureProvider<CustomerSummary>(
  (ref) => ref.watch(custRepositoryProvider).summary(),
);

/// Lịch nhận tiền cả năm (một lần gọi): Trang chủ lấy "30 ngày tới" và 2 khoản gần nhất, màn Lịch lọc 30/90/cả năm.
final custUpcomingProvider = FutureProvider<CustUpcoming>(
  (ref) => ref.watch(custRepositoryProvider).upcoming(),
);

/// Vài CCTG đang giữ cho Trang chủ.
final custHomeCertsProvider = FutureProvider<List<CustCertificate>>((
  ref,
) async {
  final page = await ref
      .watch(custRepositoryProvider)
      .certificates(scope: 'Holding', pageSize: 3);
  return page.items;
});

/// Bộ lọc danh sách CCTG: `All | Active | NearMaturity | Closed`.
class CertScopeNotifier extends Notifier<String> {
  @override
  String build() => 'All';

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

/// Bộ lọc giao dịch: `null` (tất cả) | `In` | `Out`.
class TrxDirectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties
  void set(String? v) => state = v;
}

final custTrxDirectionProvider =
    NotifierProvider<TrxDirectionNotifier, String?>(TrxDirectionNotifier.new);

class CustTransactionsNotifier extends PagedNotifier<CustTransaction> {
  @override
  Future<Paged<CustTransaction>> fetch(int page) => ref
      .read(custRepositoryProvider)
      .transactions(direction: ref.watch(custTrxDirectionProvider), page: page);
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

/// Tài liệu của một đối tượng: khoá `(type, id)` với `type` ∈ `certificates | transactions`.
final custDocumentsProvider =
    FutureProvider.family<List<CustDocument>, ({String type, String id})>(
      (ref, k) => ref.watch(custRepositoryProvider).documents(k.type, k.id),
    );

/// Mở tài liệu bằng ứng dụng hệ thống. Tách giao diện để test không cần plugin.
abstract interface class CustDocumentOpener {
  Future<bool> open(String url);
}
