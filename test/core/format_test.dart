import 'package:core_cd_mobile/core/utils/format.dart';
import 'package:core_cd_mobile/core/utils/json_converters.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('formatMoney', () {
    test('ngăn cách nghìn bằng dấu chấm và làm tròn về đồng', () {
      expect(formatMoney(Decimal.fromInt(1234567)), '1.234.567 ₫');
      expect(formatMoney(Decimal.parse('1864109.589041096')), '1.864.110 ₫');
      expect(formatMoney(Decimal.zero), '0 ₫');
      expect(formatMoney(null), '—');
    });

    test('số rất lớn không mất độ chính xác', () {
      expect(formatMoney(Decimal.parse('128412500000')), '128.412.500.000 ₫');
    });
  });

  group('formatCompact', () {
    test('rút gọn theo tỷ / triệu', () {
      expect(formatCompact(Decimal.parse('1250000000')), '1,25 tỷ');
      expect(formatCompact(Decimal.parse('3400000')), '3,4 tr');
      expect(formatCompact(Decimal.parse('950000')), '950.000');
      expect(formatCompact(Decimal.parse('1500000000000')), '1,5 nghìn tỷ');
    });
  });

  test('formatPercent nhận phần trăm, dùng dấu phẩy', () {
    expect(formatPercent(Decimal.parse('7.5')), '7,5%');
    expect(formatPercent(Decimal.parse('6.3')), '6,3%');
  });

  group('ngày nghiệp vụ (UTC)', () {
    test('không lệch ngày theo múi giờ máy', () {
      // 00:00 UTC ngày 03/10 phải luôn hiển thị 03/10 dù máy ở múi giờ nào.
      expect(formatDate(DateTime.utc(2026, 10, 3)), '03/10/2026');
      expect(formatDate(parseUtc('2026-10-03T00:00:00Z')), '03/10/2026');
    });

    test('parseUtc hiểu chuỗi không có múi giờ là UTC', () {
      final d = parseUtc('2026-07-15T00:00:00');
      expect(d.isUtc, isTrue);
      expect(formatDate(d), '15/07/2026');
    });

    test('parseUtc giữ nguyên chuỗi có múi giờ', () {
      expect(parseUtc('2026-10-13T00:00:00+00:00'), DateTime.utc(2026, 10, 13));
      expect(parseUtc('2026-10-13T07:00:00+07:00'), DateTime.utc(2026, 10, 13));
    });

    test('formatDaysFrom', () {
      final today = DateTime.utc(2026, 10, 12);
      expect(formatDaysFrom(DateTime.utc(2026, 10, 15), today), 'còn 3 ngày');
      expect(formatDaysFrom(DateTime.utc(2026, 10, 12), today), 'hôm nay');
      expect(formatDaysFrom(DateTime.utc(2026, 10, 9), today), 'quá 3 ngày');
    });
  });

  group('decimalFromJson', () {
    test('int, double và chuỗi', () {
      expect(decimalFromJson(100000000), Decimal.fromInt(100000000));
      expect(decimalFromJson(0.063), Decimal.parse('0.063'));
      expect(decimalFromJson('12.5'), Decimal.parse('12.5'));
    });

    test('double dạng khoa học không làm vỡ parse', () {
      expect(decimalFromJson(1e-7), Decimal.parse('0.0000001'));
    });

    test('giá trị lạ → FormatException', () {
      expect(() => decimalFromJson(null), throwsFormatException);
      expect(() => decimalFromJson(true), throwsFormatException);
    });
  });
}
