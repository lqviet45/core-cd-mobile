import 'package:dio/dio.dart';

import '../../../core/auth/auth_api.dart';
import '../../../core/auth/auth_models.dart';
import '../../../core/network/api_exception.dart';
import 'customer_app_dto.dart';

/// Đăng nhập SĐT/CIF + mật khẩu của app khách hàng. Dùng chung `SessionManager` (single-flight refresh, xoay vòng
/// token) bằng cách trả về `AuthTokens`; chỉ khác đường dẫn API. Dio phải là Dio **trần** (không interceptor xác thực).
///
/// Ánh xạ hồ sơ khách sang `AuthUser`: `id` = id khách, `username` = CIF; `role` không có ý nghĩa với khách
/// (không dùng để phân quyền – quyền do máy chủ quyết định theo token).
///
/// [mustChangePassword] phản ánh phản hồi gần nhất của máy chủ (đăng nhập/làm mới/đổi mật khẩu): `true` khi khách còn
/// dùng mật khẩu tạm do nhân viên cấp – lúc đó mọi API khác trả 403 cho tới khi đổi.
class CustomerAuthApi extends AuthApi {
  CustomerAuthApi(super.dio, {required super.deviceName});

  bool mustChangePassword = false;

  /// [username] là số điện thoại hoặc mã khách hàng (CIF).
  @override
  Future<AuthTokens> login(String username, String password) => _tokens(
    '/api/customer/auth/login',
    {'identifier': username, 'password': password, 'deviceName': deviceName},
  );

  @override
  Future<AuthTokens> refresh(String refreshToken) => _tokens(
    '/api/customer/auth/refresh',
    {'refreshToken': refreshToken, 'deviceName': deviceName},
  );

  /// Đổi mật khẩu (Bearer khách). Máy chủ thu hồi mọi phiên cũ và trả phiên mới cho thiết bị này.
  Future<AuthTokens> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
  }) => _tokens('/api/customer/auth/change-password', {
    'currentPassword': currentPassword,
    'newPassword': newPassword,
    'deviceName': deviceName,
  }, accessToken: accessToken);

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await dio.post<void>(
        '/api/customer/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } on DioException {
      // Đăng xuất luôn thành công ở phía thiết bị; phiên phía máy chủ tự hết hạn.
    }
  }

  Future<AuthTokens> _tokens(
    String path,
    Map<String, Object?> body, {
    String? accessToken,
  }) async {
    try {
      final res = await dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: accessToken == null
            ? null
            : Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final j = res.data!;
      final c = CustomerProfile.fromJson(j['customer'] as Map<String, dynamic>);
      mustChangePassword = j['mustChangePassword'] == true;
      return AuthTokens(
        accessToken: j['accessToken'] as String,
        accessTokenExpiresAt: DateTime.parse(
          j['accessTokenExpiresAt'] as String,
        ),
        refreshToken: j['refreshToken'] as String,
        user: AuthUser(
          id: c.id,
          username: c.cif,
          fullName: c.fullName,
          role: Role.viewer,
        ),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
