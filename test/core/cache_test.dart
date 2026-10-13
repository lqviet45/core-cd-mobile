import 'dart:convert';
import 'dart:typed_data';

import 'package:core_cd_mobile/core/cache/blob_store.dart';
import 'package:core_cd_mobile/core/cache/cache_interceptor.dart';
import 'package:core_cd_mobile/core/cache/encrypted_cache.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_api.dart';

void main() {
  late MemoryBlobStore blobs;
  late FixedCacheKeyProvider keys;
  late DateTime now;
  late EncryptedCache cache;

  setUp(() {
    blobs = MemoryBlobStore();
    keys = FixedCacheKeyProvider(List<int>.generate(32, (i) => i + 1));
    now = DateTime.utc(2026, 10, 13, 8);
    cache = EncryptedCache(blobs, keys, clock: () => now);
  });

  group('EncryptedCache', () {
    test('ghi rồi đọc lại đúng nội dung và thời điểm', () async {
      await cache.write('u1|GET /a', '{"x":1}');
      final e = await cache.read('u1|GET /a', maxAge: const Duration(days: 7));
      expect(e?.body, '{"x":1}');
      expect(e?.savedAt, now);
    });

    test('không lộ nội dung hay URL trong tên tệp và dữ liệu lưu', () async {
      const secret = 'Nguyễn Văn An CIF000482';
      await cache.write(
        'u1|http://x/api/customers?searchTerm=An',
        '{"n":"$secret"}',
      );
      final name = blobs.names.single;
      expect(name, isNot(contains('customers')));
      expect(name, matches(RegExp(r'^[0-9a-f]{64}$')));
      final raw = blobs.raw(name)!;
      expect(
        utf8.decode(raw, allowMalformed: true),
        isNot(contains('CIF000482')),
      );
      expect(utf8.decode(raw, allowMalformed: true), isNot(contains('Nguy')));
    });

    test(
      'cùng nội dung ghi hai lần cho kết quả khác nhau (nonce ngẫu nhiên)',
      () async {
        await cache.write('k', 'same');
        final a = Uint8List.fromList(blobs.raw(blobs.names.single)!);
        await cache.write('k', 'same');
        final b = blobs.raw(blobs.names.single)!;
        expect(a, isNot(equals(b)));
      },
    );

    test('sai khoá → coi như không có bản đệm, không ném lỗi', () async {
      await cache.write('k', 'data');
      final other = EncryptedCache(
        blobs,
        FixedCacheKeyProvider(List<int>.filled(32, 9)),
        clock: () => now,
      );
      expect(await other.read('k', maxAge: const Duration(days: 1)), isNull);
    });

    test('tệp bị sửa hoặc hỏng → null', () async {
      await cache.write('k', 'data');
      final name = blobs.names.single;
      final raw = Uint8List.fromList(blobs.raw(name)!);
      raw[raw.length ~/ 2] ^= 0xff;
      await blobs.write(name, raw);
      expect(await cache.read('k', maxAge: const Duration(days: 1)), isNull);
      await blobs.write(name, Uint8List.fromList([1, 2, 3]));
      expect(await cache.read('k', maxAge: const Duration(days: 1)), isNull);
    });

    test(
      'hoán đổi tệp giữa hai mục bị phát hiện (AAD gắn với khoá logic)',
      () async {
        await cache.write('a', 'A');
        await cache.write('b', 'B');
        final na = await EncryptedCache.blobName('a');
        final nb = await EncryptedCache.blobName('b');
        final bytesA = blobs.raw(na)!;
        await blobs.write(nb, bytesA);
        expect(await cache.read('b', maxAge: const Duration(days: 1)), isNull);
      },
    );

    test('quá hạn → null và bị xoá', () async {
      await cache.write('k', 'old');
      now = now.add(const Duration(days: 8));
      expect(await cache.read('k', maxAge: const Duration(days: 7)), isNull);
      expect(blobs.names, isEmpty);
    });

    test('clear xoá dữ liệu và huỷ khoá', () async {
      await cache.write('k', 'data');
      await cache.clear();
      expect(blobs.names, isEmpty);
      expect(await keys.key(), everyElement(0));
    });
  });

  group('CacheInterceptor', () {
    late FakeAdapter adapter;
    late Dio dio;
    late bool offline;
    String? user = 'u1';
    DateTime? stale;

    FakeHandler data(Object body) => (o) {
      if (offline) {
        throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        );
      }
      return ok(body);
    };

    setUp(() {
      offline = false;
      user = 'u1';
      stale = null;
      adapter = FakeAdapter({
        'GET /api/things': data({
          'items': [1, 2, 3],
        }),
        'POST /api/things': data({'created': true}),
        'GET /api/boom': (_) => failure(500, 'Lỗi máy chủ'),
      });
      dio = fakeDio(adapter)
        ..interceptors.add(
          CacheInterceptor(
            cache,
            userId: () => user,
            onServedFromCache: (t) => stale = t,
            onLive: () => stale = null,
          ),
        );
    });

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    test('online → đệm; offline → trả bản đã lưu và báo thời điểm', () async {
      await dio.get<dynamic>('/api/things');
      await settle();
      offline = true;
      final r = await dio.get<Map<String, dynamic>>('/api/things');
      expect(r.data!['items'], [1, 2, 3]);
      expect(r.extra[CacheInterceptor.fromCacheKey], isTrue);
      expect(stale, now);
      offline = false;
      await dio.get<dynamic>('/api/things');
      expect(
        stale,
        isNull,
        reason: 'có phản hồi trực tiếp thì hết "dữ liệu cũ"',
      );
    });

    test('offline mà chưa từng đệm → lỗi mạng như bình thường', () async {
      offline = true;
      await expectLater(
        dio.get<dynamic>('/api/things'),
        throwsA(isA<DioException>()),
      );
      expect(stale, isNull);
    });

    test('lệnh ghi không được đệm và không phục vụ từ đệm', () async {
      await dio.post<dynamic>('/api/things');
      await settle();
      expect(blobs.names, isEmpty);
      await dio.get<dynamic>('/api/things');
      await settle();
      offline = true;
      await expectLater(
        dio.post<dynamic>('/api/things'),
        throwsA(isA<DioException>()),
      );
    });

    test('lỗi từ máy chủ (500) không bị thay bằng bản đệm', () async {
      await expectLater(
        dio.get<dynamic>('/api/boom'),
        throwsA(isA<DioException>()),
      );
      expect(stale, isNull);
    });

    test('người dùng khác không đọc được bản đệm của người trước', () async {
      await dio.get<dynamic>('/api/things');
      await settle();
      user = 'u2';
      offline = true;
      await expectLater(
        dio.get<dynamic>('/api/things'),
        throwsA(isA<DioException>()),
      );
    });

    test('chưa đăng nhập thì không đệm gì', () async {
      user = null;
      await dio.get<dynamic>('/api/things');
      await settle();
      expect(blobs.names, isEmpty);
    });

    test('sau khi xoá đệm (đăng xuất) offline không còn dữ liệu', () async {
      await dio.get<dynamic>('/api/things');
      await settle();
      await cache.clear();
      offline = true;
      await expectLater(
        dio.get<dynamic>('/api/things'),
        throwsA(isA<DioException>()),
      );
    });
  });
}
