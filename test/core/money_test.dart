import 'package:core_cd_mobile/core/money/idempotency.dart';
import 'package:core_cd_mobile/core/ui/money_field.dart';
import 'package:core_cd_mobile/features/trading/presentation/sell_screen.dart'
    show parseRatePercent;
import 'package:core_cd_mobile/features/trading/presentation/trading_providers.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Idempotency-Key', () {
    test('đúng định dạng UUID v4 và không trùng nhau', () {
      final re = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final keys = {for (var i = 0; i < 500; i++) newIdempotencyKey()};
      expect(keys, hasLength(500));
      expect(keys.every(re.hasMatch), isTrue);
    });
  });

  group('Ô nhập tiền VND', () {
    TextEditingValue fmt(String t) => const VndInputFormatter()
        .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: t));

    test('nhóm hàng nghìn, bỏ ký tự lạ và số 0 đầu', () {
      expect(fmt('1234567').text, '1.234.567');
      expect(fmt('12a3b4').text, '1.234');
      expect(fmt('0005000').text, '5.000');
      expect(fmt('').text, '');
      expect(fmt('abc').text, '');
    });

    test('parseVnd đọc lại đúng, kể cả số rất lớn (không qua double)', () {
      expect(parseVnd('1.234.567'), Decimal.fromInt(1234567));
      expect(
        parseVnd('9.007.199.254.740.993'),
        Decimal.parse('9007199254740993'),
      );
      expect(parseVnd(''), isNull);
    });

    test('jsonNum: số nguyên khi không có phần lẻ, double khi có', () {
      expect(jsonNum(Decimal.fromInt(500000000)), 500000000);
      expect(jsonNum(Decimal.parse('0.001')), 0.001);
      expect(jsonNum(Decimal.parse('1000000.00')), 1000000);
    });
  });

  group('Lãi suất không kỳ hạn', () {
    test('đổi % sang tỉ lệ và chặn giá trị sai', () {
      expect(parseRatePercent('0,1'), Decimal.parse('0.001'));
      expect(parseRatePercent('0.1'), Decimal.parse('0.001'));
      expect(parseRatePercent('7,5'), Decimal.parse('0.075'));
      expect(parseRatePercent(''), isNull);
      expect(parseRatePercent('abc'), isNull);
      expect(parseRatePercent('-1'), isNull);
      expect(parseRatePercent('101'), isNull);
    });
  });

  group('Lãi dự kiến (cùng công thức với web)', () {
    test('500 triệu · 7,5% · 355 ngày', () {
      expect(
        estimateInterest(Decimal.fromInt(500000000), Decimal.parse('7.5'), 355),
        Decimal.fromInt(36472603),
      );
    });

    test('số ngày ≤ 0 → 0; làm tròn đồng (half-up)', () {
      expect(
        estimateInterest(Decimal.fromInt(1000000), Decimal.fromInt(5), 0),
        Decimal.zero,
      );
      expect(
        estimateInterest(Decimal.fromInt(1000000), Decimal.fromInt(5), -3),
        Decimal.zero,
      );
      // 1.000.000 × 5% × 30 / 365 = 4109,589… → 4110
      expect(
        estimateInterest(Decimal.fromInt(1000000), Decimal.fromInt(5), 30),
        Decimal.fromInt(4110),
      );
    });

    test('daysBetween theo ngày lịch', () {
      expect(
        daysBetween(DateTime.utc(2026, 10, 12), DateTime.utc(2027, 10, 2)),
        355,
      );
    });
  });
}
