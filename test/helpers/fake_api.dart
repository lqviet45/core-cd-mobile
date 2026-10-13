import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = ({int status, Object? body}) Function(
  RequestOptions options,
);

/// Máy chủ giả cho Dio: ánh xạ `METHOD path` → phản hồi. Ghi lại mọi request để test kiểm tra.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.routes);

  final Map<String, FakeHandler> routes;
  final List<RequestOptions> requests = [];

  int count(String key) =>
      requests.where((r) => '${r.method} ${r.path}' == key).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = routes['${options.method} ${options.path}'];
    if (handler == null) {
      return ResponseBody.fromString(
        jsonEncode({
          'title': 'Không có route giả: ${options.method} ${options.path}',
        }),
        404,
        headers: _json,
      );
    }
    final r = handler(options);
    return ResponseBody.fromString(
      jsonEncode(r.body),
      r.status,
      headers: _json,
    );
  }

  static const _json = {
    Headers.contentTypeHeader: ['application/json'],
  };

  @override
  void close({bool force = false}) {}
}

({int status, Object? body}) ok(Object? body) => (status: 200, body: body);
({int status, Object? body}) failure(int status, [String? title]) =>
    (status: status, body: {'title': ?title});

Dio fakeDio(FakeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://fake'))..httpClientAdapter = adapter;
