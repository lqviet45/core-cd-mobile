/// Cấu hình theo môi trường, truyền lúc build bằng `--dart-define-from-file=env/<flavor>.json`.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.envName,
    this.supportPhone = '',
    this.sentryDsn = '',
    this.appVersion = '',
    this.requestTimeout = const Duration(seconds: 20),
  });

  // Đừng để `dart fix` xoá 3 dòng dưới: giá trị mặc định '' trùng default của tham số nhưng
  // `String.fromEnvironment` mới là thứ đọc `--dart-define` (đã từng mất vì lint này).
  // ignore_for_file: avoid_redundant_argument_values

  /// Đọc từ `--dart-define`. Địa chỉ mặc định `10.0.2.2` là máy chủ của host khi chạy trên emulator Android.
  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5080',
    ),
    envName: String.fromEnvironment('ENV_NAME', defaultValue: 'dev'),
    supportPhone: String.fromEnvironment('SUPPORT_PHONE'),
    sentryDsn: String.fromEnvironment('SENTRY_DSN'),
    appVersion: String.fromEnvironment('APP_VERSION'),
  );

  final String apiBaseUrl;
  final String envName;

  /// Số hotline hỗ trợ khách hàng (`SUPPORT_PHONE`). Rỗng = chưa cấu hình → app chỉ hiện hướng dẫn chung.
  final String supportPhone;

  /// DSN Sentry (`SENTRY_DSN`). Rỗng = tắt báo lỗi.
  final String sentryDsn;

  /// Phiên bản gắn vào báo lỗi (`APP_VERSION`), vd `1.0.0+3`.
  final String appVersion;
  final Duration requestTimeout;

  bool get isProd => envName == 'prod';

  /// Bản production bắt buộc dùng HTTPS: access token và refresh token không được đi qua kênh không mã hoá.
  void validate() {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('API_BASE_URL không hợp lệ: "$apiBaseUrl"');
    }
    if (isProd && uri.scheme != 'https') {
      throw StateError('Môi trường prod bắt buộc API_BASE_URL dùng https.');
    }
  }
}
