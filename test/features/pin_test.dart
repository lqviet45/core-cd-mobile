import 'dart:async';
import 'dart:convert';

import 'package:core_cd_mobile/core/auth/pin_service.dart';
import 'package:core_cd_mobile/core/auth/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_api.dart';

const _uid = 'c7b9e9ad-5683-40ca-a536-1df8f9f6c678';

Future<void> _enter(WidgetTester t, String pin) async {
  for (final d in pin.split('')) {
    await t.tap(find.text(d).last);
    await t.pump(const Duration(milliseconds: 30));
  }
  await t.pumpAndSettle();
}

Map<String, FakeHandler> get _routes => {
  'GET /api/auth/sessions': (_) => ok(<Object>[]),
  'GET /api/notifications/preferences': (_) => ok(<Object>[]),
  'POST /api/auth/logout': (_) => ok(null),
};

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('PinService', () {
    late InMemoryPinStorage store;
    late PinService svc;
    setUp(() {
      store = InMemoryPinStorage();
      svc = PinService(store, iterations: 1000);
    });

    test('chính sách PIN', () {
      expect(pinProblem('48291'), isNotNull, reason: 'thiếu số');
      expect(pinProblem('4829133'), isNotNull, reason: 'thừa số');
      expect(pinProblem('48a913'), isNotNull);
      expect(pinProblem('111111'), contains('giống nhau'));
      expect(pinProblem('123456'), contains('liên tiếp'));
      expect(pinProblem('654321'), contains('liên tiếp'));
      expect(pinProblem('482913'), isNull);
    });

    test(
      'không lưu PIN dạng rõ; hai lần đặt cho muối và băm khác nhau',
      () async {
        await svc.set(_uid, '482913');
        final raw = store.data['core_cd.pin.$_uid']!;
        expect(raw.contains('482913'), isFalse);
        final first = jsonDecode(raw) as Map<String, dynamic>;
        await svc.set(_uid, '482913');
        final second = jsonDecode(
          store.data['core_cd.pin.$_uid']!,
        ) as Map<String, dynamic>;
        expect(first['s'], isNot(second['s']));
        expect(first['h'], isNot(second['h']));
      },
    );

    test('đặt PIN yếu bị từ chối', () async {
      expect(() => svc.set(_uid, '123456'), throwsArgumentError);
      expect(await svc.isSet(_uid), isFalse);
    });

    test(
      'đúng → ok; sai → còn bao nhiêu lần; đúng lại → đếm lại từ đầu',
      () async {
        await svc.set(_uid, '482913');
        expect(await svc.verify(_uid, '482913'), isA<PinOk>());
        expect((await svc.verify(_uid, '000001') as PinWrong).attemptsLeft, 4);
        expect((await svc.verify(_uid, '000002') as PinWrong).attemptsLeft, 3);
        expect(await svc.verify(_uid, '482913'), isA<PinOk>());
        expect((await svc.verify(_uid, '000003') as PinWrong).attemptsLeft, 4);
      },
    );

    test('sai đủ 5 lần → xoá PIN; đúng sau đó cũng không vào được', () async {
      await svc.set(_uid, '482913');
      for (var i = 0; i < 4; i++) {
        expect(await svc.verify(_uid, '00000$i'), isA<PinWrong>());
      }
      expect(await svc.verify(_uid, '000009'), isA<PinLockedOut>());
      expect(await svc.isSet(_uid), isFalse);
      expect(await svc.verify(_uid, '482913'), isA<PinLockedOut>());
    });

    test(
      'số lần sai được lưu bền: dựng lại dịch vụ (tắt/mở app) không đếm lại',
      () async {
        await svc.set(_uid, '482913');
        await svc.verify(_uid, '000001');
        await svc.verify(_uid, '000002');
        final again = PinService(store, iterations: 1000);
        expect(
          (await again.verify(_uid, '000003') as PinWrong).attemptsLeft,
          2,
        );
      },
    );

    test('secure storage lỗi: coi như chưa đặt PIN, không ném lỗi', () async {
      final broken = PinService(_ThrowingStorage(), iterations: 1000);
      expect(await broken.isSet(_uid), isFalse);
    });

    test('PIN của tài khoản này không mở được tài khoản khác', () async {
      await svc.set(_uid, '482913');
      expect(await svc.isSet('other-user'), isFalse);
      expect(await svc.verify('other-user', '482913'), isA<PinLockedOut>());
    });
  });

  group('Màn khoá', () {
    testWidgets(
      'có PIN + sinh trắc hỏng: hiện bàn phím PIN; đúng PIN mở khoá',
      (t) async {
        final h = await pumpSignedIn(
          t,
          routes: _routes,
          pin: '482913',
          bioPasses: false,
        );
        expect(find.textContaining('Nhập mã PIN'), findsOneWidget);
        expect(find.text('Đăng nhập bằng mật khẩu'), findsOneWidget);
        await _enter(t, '482913');
        expect(h.router.routeInformationProvider.value.uri.path, '/home');
      },
    );

    testWidgets('sai PIN: báo còn mấy lần, vẫn ở màn khoá', (t) async {
      final h = await pumpSignedIn(
        t,
        routes: _routes,
        pin: '482913',
        bioPasses: false,
      );
      await _enter(t, '000001');
      expect(find.textContaining('Còn 4 lần thử'), findsOneWidget);
      expect(h.router.routeInformationProvider.value.uri.path, '/lock');
    });

    testWidgets('sai 5 lần: xoá PIN và đăng xuất (phải nhập lại mật khẩu)', (
      t,
    ) async {
      final h = await pumpSignedIn(
        t,
        routes: _routes,
        pin: '482913',
        bioPasses: false,
      );
      for (var i = 1; i <= 5; i++) {
        await _enter(t, '00000$i');
      }
      expect(h.router.routeInformationProvider.value.uri.path, '/login');
      expect(
        h.pins.data.keys.where((k) => k.startsWith('core_cd.pin')),
        isEmpty,
      );
      expect(h.adapter.count('POST /api/auth/logout'), 1);
    });

    testWidgets('"Đăng nhập bằng mật khẩu" đăng xuất và xoá PIN', (t) async {
      final h = await pumpSignedIn(
        t,
        routes: _routes,
        pin: '482913',
        bioPasses: false,
      );
      await t.tap(find.text('Đăng nhập bằng mật khẩu'));
      await t.pumpAndSettle();
      expect(h.router.routeInformationProvider.value.uri.path, '/login');
      expect(
        h.pins.data.keys.where((k) => k.startsWith('core_cd.pin')),
        isEmpty,
      );
    });

    testWidgets('có PIN: vân tay vẫn mở được và không cần gõ PIN', (t) async {
      final h = await pumpSignedIn(t, routes: _routes, pin: '482913');
      expect(h.router.routeInformationProvider.value.uri.path, '/home');
      expect(h.bio.prompts, greaterThan(0));
    });

    testWidgets('chưa đặt PIN: giữ nguyên màn khoá sinh trắc cũ', (t) async {
      await pumpSignedIn(t, routes: _routes, bioPasses: false);
      expect(find.text('Ứng dụng đã khoá'), findsOneWidget);
      expect(find.text('Mở khoá'), findsOneWidget);
    });
  });

  group('Cài đặt PIN', () {
    Future<Harness> open(WidgetTester t, {String? pin}) async {
      final h = await pumpSignedIn(t, routes: _routes, pin: pin);
      await h.go('/more/account');
      return h;
    }

    testWidgets('đặt PIN mới: tạo → nhập lại → lưu băm', (t) async {
      final h = await open(t);
      expect(find.text('Mở app nhanh bằng mã 6 số'), findsOneWidget);
      await t.tap(find.text('Mã PIN'));
      await t.pumpAndSettle();
      expect(find.text('Tạo mã PIN mới'), findsOneWidget);
      await _enter(t, '482913');
      expect(find.text('Nhập lại mã PIN'), findsOneWidget);
      await _enter(t, '482913');
      expect(h.pins.data.containsKey('core_cd.pin.$_uid'), isTrue);
      expect(find.text('Đã bật · 6 chữ số'), findsOneWidget);
    });

    testWidgets('PIN yếu bị từ chối ngay, không sang bước nhập lại', (t) async {
      final h = await open(t);
      await t.tap(find.text('Mã PIN'));
      await t.pumpAndSettle();
      await _enter(t, '123456');
      expect(find.text('PIN không được là dãy số liên tiếp.'), findsOneWidget);
      expect(find.text('Tạo mã PIN mới'), findsOneWidget);
      expect(h.pins.data.containsKey('core_cd.pin.$_uid'), isFalse);
    });

    testWidgets('nhập lại không khớp: quay về bước tạo, không lưu', (t) async {
      final h = await open(t);
      await t.tap(find.text('Mã PIN'));
      await t.pumpAndSettle();
      await _enter(t, '482913');
      await _enter(t, '482914');
      expect(find.textContaining('không khớp'), findsOneWidget);
      expect(find.text('Tạo mã PIN mới'), findsOneWidget);
      expect(h.pins.data.containsKey('core_cd.pin.$_uid'), isFalse);
    });

    testWidgets('đổi PIN: phải nhập đúng PIN hiện tại trước', (t) async {
      final h = await open(t, pin: '482913');
      await t.tap(find.text('Mã PIN'));
      await t.pumpAndSettle();
      await t.tap(find.text('Đổi mã PIN'));
      await t.pumpAndSettle();
      expect(find.text('Nhập mã PIN hiện tại'), findsOneWidget);
      await _enter(t, '000001');
      expect(find.textContaining('Còn 4 lần thử'), findsOneWidget);
      await _enter(t, '482913');
      expect(find.text('Tạo mã PIN mới'), findsOneWidget);
      await _enter(t, '703815');
      await _enter(t, '703815');
      final svc = PinService(h.pins, iterations: 1000);
      expect(await svc.verify(_uid, '703815'), isA<PinOk>());
    });

    testWidgets('tắt PIN: cần PIN hiện tại, sau đó xoá hẳn', (t) async {
      final h = await open(t, pin: '482913');
      await t.tap(find.text('Mã PIN'));
      await t.pumpAndSettle();
      await t.tap(find.text('Tắt mã PIN'));
      await t.pumpAndSettle();
      await _enter(t, '482913');
      expect(h.pins.data.containsKey('core_cd.pin.$_uid'), isFalse);
      expect(find.text('Mở app nhanh bằng mã 6 số'), findsOneWidget);
    });
  });

  testWidgets('đăng xuất xoá PIN của tài khoản', (t) async {
    final h = await pumpSignedIn(t, routes: _routes, pin: '482913');
    expect(h.pins.data.containsKey('core_cd.pin.$_uid'), isTrue);
    unawaited(h.container.read(authControllerProvider.notifier).logout());
    await t.pumpAndSettle();
    expect(h.pins.data.containsKey('core_cd.pin.$_uid'), isFalse);
  });
}

class _ThrowingStorage implements PinStorage {
  @override
  Future<String?> read(String key) async => throw Exception('keystore hỏng');

  @override
  Future<void> write(String key, String value) async =>
      throw Exception('keystore hỏng');

  @override
  Future<void> delete(String key) async => throw Exception('keystore hỏng');
}
