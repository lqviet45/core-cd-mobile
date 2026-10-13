import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/money/idempotency.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/format.dart';
import '../../customers/data/customer_dto.dart';
import '../../dashboard/data/dashboard_dto.dart';
import '../../lots/data/lot_dto.dart';
import '../../transactions/data/trade_dto.dart';

/// Lô đang mở và còn hạn mức, dùng để chọn khi mua.
final openLotsProvider = FutureProvider.autoDispose<List<Lot>>((ref) async {
  final lots = await ref.watch(lotRepositoryProvider).list(status: 'Open');
  return lots.where((l) => l.remainingFaceValue > Decimal.zero).toList();
});

/// Số ngày giữa hai ngày nghiệp vụ (UTC).
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Lãi dự kiến = gốc × lãi suất(%/năm) × số ngày / 365, làm tròn đồng (cùng công thức với web).
Decimal estimateInterest(Decimal principal, Decimal annualRatePct, int days) {
  if (days <= 0) return Decimal.zero;
  return (principal *
          annualRatePct *
          Decimal.fromInt(days) /
          Decimal.fromInt(36500))
      .toDecimal(scaleOnInfinitePrecision: 6)
      .round();
}

/// Nháp lệnh mua qua 3 bước. `key` là Idempotency-Key, sinh **một lần** khi mở form và giữ nguyên khi thử lại.
class BuyDraft {
  const BuyDraft({
    required this.key,
    required this.issueDate,
    this.customer,
    this.lot,
    this.principal,
  });

  final String key;
  final DateTime issueDate;
  final Customer? customer;
  final Lot? lot;
  final Decimal? principal;

  BuyDraft copyWith({
    Customer? customer,
    bool clearCustomer = false,
    Lot? lot,
    Decimal? principal,
    bool clearPrincipal = false,
    DateTime? issueDate,
  }) => BuyDraft(
    key: key,
    issueDate: issueDate ?? this.issueDate,
    customer: clearCustomer ? null : (customer ?? this.customer),
    lot: lot ?? this.lot,
    principal: clearPrincipal ? null : (principal ?? this.principal),
  );

  int get termDays =>
      lot == null ? 0 : daysBetween(issueDate, lot!.maturityDate);

  Decimal get interest => lot == null || principal == null
      ? Decimal.zero
      : estimateInterest(principal!, lot!.annualRatePct, termDays);

  String? get principalError {
    final p = principal;
    final l = lot;
    if (p == null || l == null) return null;
    if (p < l.minPurchaseAmount) {
      return 'Tối thiểu ${formatMoney(l.minPurchaseAmount)}.';
    }
    if (p > l.remainingFaceValue) {
      return 'Vượt hạn mức còn lại ${formatMoney(l.remainingFaceValue)}.';
    }
    return null;
  }

  String? get dateError {
    final l = lot;
    if (l == null) return null;
    final d = DateTime.utc(issueDate.year, issueDate.month, issueDate.day);
    if (d.isBefore(l.issueDate) || termDays <= 0) {
      return 'Ngày phát hành phải nằm trong thời gian hiệu lực của lô.';
    }
    return null;
  }

  bool get amountValid =>
      customer != null &&
      lot != null &&
      principal != null &&
      principalError == null &&
      dateError == null;
}

class BuyDraftNotifier extends Notifier<BuyDraft> {
  @override
  BuyDraft build() =>
      BuyDraft(key: newIdempotencyKey(), issueDate: todayBusinessDate());

  void setCustomer(Customer? c) =>
      state = state.copyWith(customer: c, clearCustomer: c == null);
  void setLot(Lot l) => state = state.copyWith(lot: l, clearPrincipal: true);
  void setPrincipal(Decimal? p) =>
      state = state.copyWith(principal: p, clearPrincipal: p == null);
  void setIssueDate(DateTime d) => state = state.copyWith(issueDate: d);
}

final buyDraftProvider =
    NotifierProvider.autoDispose<BuyDraftNotifier, BuyDraft>(
      BuyDraftNotifier.new,
    );

/// Theo dõi một giao dịch: hỏi lại mỗi 1,5 giây cho tới khi kết thúc (thành công/thất bại).
/// Lỗi mạng tạm thời không làm mất màn hình theo dõi: giữ giá trị cuối và thử lại.
final transactionWatchProvider = StreamProvider.autoDispose
    .family<Transaction, String>((ref, id) async* {
      var disposed = false;
      ref.onDispose(() => disposed = true);
      final repo = ref.watch(transactionRepositoryProvider);
      while (!disposed) {
        try {
          final t = await repo.get(id);
          if (disposed) return;
          yield t;
          if (t.isTerminal) return;
        } on ApiException catch (e) {
          if (!e.isNetwork) rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
    });

/// Xem trước lệnh bán do máy chủ tính.
final sellPreviewProvider = FutureProvider.autoDispose
    .family<SellPreview, SellParams>(
      (ref, p) => ref.watch(transactionRepositoryProvider).previewSell(p),
    );
