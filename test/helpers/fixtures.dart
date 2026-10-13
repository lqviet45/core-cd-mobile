import 'dart:convert';
import 'dart:io';

/// Đọc fixture JSON (dữ liệu thật lấy từ backend bằng `tool/capture_fixtures.mjs`).
Object? fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

Map<String, dynamic> fixtureMap(String name) =>
    fixture(name)! as Map<String, dynamic>;
