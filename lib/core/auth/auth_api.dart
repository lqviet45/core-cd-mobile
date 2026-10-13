import 'package:dio/dio.dart';

import '../network/api_exception.dart';
import 'auth_models.dart';

/// Các lời gọi xác thực. Dùng một [Dio] **trần** (không interceptor xác thực) để việc làm mới token
/// không tự gọi lại chính nó khi gặp 401.
///
/// Mobile **không** gửi `X-Auth-Mode: cookie`: refresh token trả trong body.
class AuthApi {
  AuthApi(this._dio, {required this.deviceName});

  final Dio _dio;
  final String deviceName;

  Future<AuthTokens> login(String username, String password) => _post(
    '/api/auth/login',
    {'username': username, 'password': password, 'deviceName': deviceName},
  );

  Future<AuthTokens> refresh(String refreshToken) => _post(
    '/api/auth/refresh',
    {'refreshToken': refreshToken, 'deviceName': deviceName},
  );

  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<void>(
        '/api/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } on DioException {
      // Đăng xuất phải luôn thành công ở phía thiết bị; phiên phía máy chủ sẽ tự hết hạn.
    }
  }

  Future<AuthTokens> _post(String path, Map<String, Object?> body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      return AuthTokens.fromJson(res.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
