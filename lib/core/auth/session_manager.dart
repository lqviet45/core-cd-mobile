import 'dart:async';

import '../network/api_exception.dart';
import 'auth_api.dart';
import 'auth_models.dart';
import 'token_store.dart';

enum RefreshResult {
  /// Có access token mới.
  ok,

  /// Refresh token không còn hợp lệ (hết hạn/đã thu hồi) → phải đăng nhập lại.
  invalid,

  /// Không làm mới được vì lỗi tạm thời (mạng, 5xx): giữ phiên, thử lại sau.
  unavailable,
}

sealed class SessionEvent {
  const SessionEvent();
}

class SignedIn extends SessionEvent {
  const SignedIn(this.user);
  final AuthUser user;
}

class SignedOut extends SessionEvent {
  const SignedOut({this.expired = false});

  /// true = phiên bị máy chủ từ chối (hết hạn/thu hồi), không phải người dùng tự đăng xuất.
  final bool expired;
}

/// Giữ access token trong bộ nhớ, refresh token ở [TokenStore] và điều phối việc làm mới.
///
/// Refresh token **xoay vòng và chỉ dùng được một lần**; dùng lại token đã xoay bị backend coi là bị đánh cắp
/// và đăng xuất mọi thiết bị. Vì vậy mọi lời gọi làm mới chạy **single-flight**: các request đồng thời cùng chờ
/// một lần làm mới duy nhất.
class SessionManager {
  SessionManager({
    required this._store,
    required this._api,
    DateTime Function()? clock,
    this.refreshSkew = const Duration(seconds: 30),
  }) : _now = clock ?? DateTime.now;

  final TokenStore _store;
  final AuthApi _api;
  final DateTime Function() _now;

  /// Làm mới trước khi access token hết hạn khoảng này để tránh 401 không cần thiết.
  final Duration refreshSkew;

  final _events = StreamController<SessionEvent>.broadcast();
  String? _accessToken;
  DateTime? _accessExpiresAt;
  AuthUser? _user;
  Future<RefreshResult>? _refreshing;

  Stream<SessionEvent> get events => _events.stream;
  AuthUser? get user => _user;
  String? get accessToken => _accessToken;

  bool get _accessTokenFresh =>
      _accessToken != null &&
      _accessExpiresAt != null &&
      _accessExpiresAt!.difference(_now()) > refreshSkew;

  /// Khôi phục phiên khi mở app. Trả về `null` nếu chưa đăng nhập; ném lỗi mạng nếu không xác định được
  /// (khi đó refresh token vẫn được giữ lại).
  Future<AuthUser?> restore() async {
    final stored = await _store.readRefreshToken();
    if (stored == null) return null;
    final result = await refresh();
    if (result == RefreshResult.invalid) return null;
    if (result == RefreshResult.unavailable) {
      throw const ApiException(
        status: 0,
        message: 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.',
      );
    }
    return _user;
  }

  Future<AuthUser> login(String username, String password) =>
      _api.login(username.trim(), password).then(signIn);

  /// Nhận một cặp token đã có (vd. sau khi xác thực OTP ở app khách hàng) làm phiên hiện tại.
  Future<AuthUser> signIn(AuthTokens tokens) async {
    await _adopt(tokens);
    _events.add(SignedIn(tokens.user));
    return tokens.user;
  }

  /// Bảo đảm có access token còn hạn trước khi gọi API; trả về false nếu không thể (đã đăng xuất/lỗi mạng).
  Future<bool> ensureFresh() async {
    if (_accessTokenFresh) return true;
    if (_accessToken == null && await _store.readRefreshToken() == null) {
      return false;
    }
    return await refresh() == RefreshResult.ok;
  }

  Future<RefreshResult> refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<RefreshResult> _doRefresh() async {
    final stored = await _store.readRefreshToken();
    if (stored == null) return RefreshResult.invalid;
    try {
      final tokens = await _api.refresh(stored);
      await _adopt(tokens);
      return RefreshResult.ok;
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) {
        await _clear();
        _events.add(const SignedOut(expired: true));
        return RefreshResult.invalid;
      }
      return RefreshResult.unavailable;
    }
  }

  /// Đăng xuất chủ động: thu hồi phiên phía máy chủ (nếu được) rồi xoá dữ liệu cục bộ.
  Future<void> logout() async {
    final stored = await _store.readRefreshToken();
    if (stored != null) await _api.logout(stored);
    await _clear();
    _events.add(const SignedOut());
  }

  Future<void> _adopt(AuthTokens t) async {
    // Lưu refresh token MỚI trước: nếu app bị tắt ngay sau đó, token cũ đã bị xoay nên không dùng lại được.
    await _store.saveRefreshToken(t.refreshToken);
    _accessToken = t.accessToken;
    _accessExpiresAt = t.accessTokenExpiresAt;
    _user = t.user;
  }

  Future<void> _clear() async {
    await _store.clear();
    _accessToken = null;
    _accessExpiresAt = null;
    _user = null;
  }

  Future<void> dispose() => _events.close();
}
