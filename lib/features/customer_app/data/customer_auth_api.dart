import 'package:dio/dio.dart';

import '../../../core/auth/auth_api.dart';
import '../../../core/auth/auth_models.dart';
import '../../../core/network/api_exception.dart';
import 'customer_app_dto.dart';

/// Đăng nhập OTP của app khách hàng. Dùng chung `SessionManager` (single-flight refresh, xoay vòng token) bằng cách
/// trả về `AuthTokens`; chỉ khác đường dẫn API. Dio phải là Dio **trần** (không interceptor xác thực).
///
/// Ánh xạ hồ sơ khách sang `AuthUser`: `id` = id khách, `username` = CIF; `role` không có ý nghĩa với khách
/// (không dùng để phân quyền – quyền do máy chủ quyết định theo token).
class CustomerAuthApi extends AuthApi {
  CustomerAuthApi(super.dio, {required super.deviceName});

  Future<OtpRequested> requestOtp(String phone) async {
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/api/customer/auth/otp/request',
        data: {'phone': phone},
      );
      return OtpRequested.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<AuthTokens> verifyOtp(String phone, String code) => _tokens(
    '/api/customer/auth/otp/verify',
    {'phone': phone, 'code': code, 'deviceName': deviceName},
  );

  @override
  Future<AuthTokens> login(String username, String password) =>
      throw UnsupportedError('Khách hàng đăng nhập bằng OTP.');

  @override
  Future<AuthTokens> refresh(String refreshToken) => _tokens(
    '/api/customer/auth/refresh',
    {'refreshToken': refreshToken, 'deviceName': deviceName},
  );

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

  Future<AuthTokens> _tokens(String path, Map<String, Object?> body) async {
    try {
      final res = await dio.post<Map<String, dynamic>>(path, data: body);
      final j = res.data!;
      final c = CustomerProfile.fromJson(j['customer'] as Map<String, dynamic>);
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
