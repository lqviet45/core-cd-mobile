/// Cấu hình theo môi trường, truyền lúc build bằng `--dart-define-from-file=env/<flavor>.json`.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.envName,
    this.requestTimeout = const Duration(seconds: 20),
  });

  /// Đọc từ `--dart-define`. Địa chỉ mặc định `10.0.2.2` là máy chủ của host khi chạy trên emulator Android.
  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5080',
    ),
    envName: String.fromEnvironment('ENV_NAME', defaultValue: 'dev'),
  );

  final String apiBaseUrl;
  final String envName;
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
