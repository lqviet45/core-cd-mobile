import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

import '../../../core/models/paged.dart';
import '../../../core/network/api_call.dart';
import '../../../core/ui/money_field.dart';
import '../../../core/utils/format.dart';
import '../../dashboard/data/dashboard_dto.dart';
import 'trade_dto.dart';

class TransactionRepository {
  TransactionRepository(this._dio);
  final Dio _dio;

  Future<Paged<Transaction>> list({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? cif,
  }) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/transactions',
      queryParameters: cleanQuery({
        'pageNumber': page,
        'pageSize': pageSize,
        'status': status,
        'cif': cif,
      }),
    );
    return Paged.fromJson(res.data!, Transaction.fromJson);
  });

  Future<Transaction> get(String id) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/transactions/$id');
    return Transaction.fromJson(res.data!);
  });

  /// Tạo lệnh mua. [idempotencyKey] sinh một lần khi mở form và giữ nguyên khi gửi lại.
  Future<TrxCreated> buy({
    required String customerId,
    required String lotId,
    required Decimal principal,
    required DateTime issueDate,
    required String idempotencyKey,
    String? notes,
  }) => apiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/transactions/buy',
      data: {
        'customerId': customerId,
        'lotId': lotId,
        'principal': jsonNum(principal),
        'issueDate': formatIsoDate(issueDate),
        'notes': notes,
        'channel': 'MOBILE',
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return TrxCreated.fromJson(res.data!);
  });

  Map<String, Object?> _sellBody(SellParams p) => {
    'customerId': p.customerId,
    'sellType': p.sellType,
    'quantity': p.sellType == 'Quantity' ? p.quantity : null,
    'targetAmount': p.sellType == 'Amount' && p.targetAmount != null
        ? jsonNum(p.targetAmount!)
        : null,
    'redemptionDate': formatIsoDate(p.redemptionDate),
    'demandRate': jsonNum(p.demandRate),
  };

  Future<SellPreview> previewSell(SellParams p) => apiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/transactions/sell/preview',
      data: _sellBody(p),
    );
    return SellPreview.fromJson(res.data!);
  });

  Future<TrxCreated> sell(SellParams p, {required String idempotencyKey}) =>
      apiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/api/transactions/sell',
          data: {..._sellBody(p), 'channel': 'MOBILE'},
          options: Options(headers: {'Idempotency-Key': idempotencyKey}),
        );
        return TrxCreated.fromJson(res.data!);
      });

  /// Tạo lại lệnh từ giao dịch thất bại (mỗi giao dịch chỉ tạo lại được một lần).
  Future<TrxCreated> retry(String id) => apiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/transactions/$id/retry',
    );
    return TrxCreated.fromJson(res.data!);
  });
}
