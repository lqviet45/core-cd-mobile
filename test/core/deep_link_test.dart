import 'package:core_cd_mobile/core/utils/deep_link.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '61781d08-6945-4798-b0f1-6918645b0916';

void main() {
  group('routeForLink', () {
    test('đường dẫn web → màn hình mobile', () {
      expect(routeForLink('/lots/$_id'), '/more/lots/$_id');
      expect(routeForLink('/transactions/$_id'), '/transactions/$_id');
      expect(routeForLink('/settlement'), '/more/maturities');
      expect(routeForLink('/transactions'), '/transactions');
    });

    test('không có đích hợp lệ → null (không điều hướng bừa)', () {
      expect(routeForLink(null), isNull);
      expect(routeForLink(''), isNull);
      expect(routeForLink('/unknown'), isNull);
      expect(routeForLink('/lots/not-a-guid'), isNull);
      expect(routeForLink('https://evil.example/transactions/$_id'), isNull);
      expect(routeForLink('/transactions/$_id/../../x'), isNull);
    });
  });

  group('routeForPush', () {
    test('ưu tiên link', () {
      expect(
        routeForPush({'link': '/transactions/$_id', 'type': 'NearMaturity'}),
        '/transactions/$_id',
      );
    });

    test('thiếu link → suy từ loại thông báo', () {
      expect(routeForPush({'type': 'NearMaturity'}), '/more/maturities');
      expect(routeForPush({'type': 'TransactionFailed'}), '/transactions');
      expect(routeForPush({'type': 'LotNearlySoldOut'}), '/more/lots');
    });

    test('loại lạ hoặc link lạ → hộp thông báo', () {
      expect(routeForPush({'type': 'Something'}), '/notifications');
      expect(routeForPush(const {}), '/notifications');
      expect(
        routeForPush({'link': '/evil', 'type': 'JobSummary'}),
        '/notifications',
      );
    });
  });
}
