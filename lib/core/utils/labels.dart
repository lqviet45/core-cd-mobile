import 'package:flutter/material.dart';

/// Sắc thái của nhãn trạng thái; ánh xạ sang màu ở `core/ui/theme.dart`.
enum Tone { neutral, success, warning, danger, info }

typedef Labeled = ({String label, Tone tone});

/// Trạng thái CCTG (backend trả mã tiếng Anh).
Labeled certStatusOf(String code) => switch (code) {
  'Active' => (label: 'Đang hoạt động', tone: Tone.success),
  'NearMaturity' => (label: 'Sắp đáo hạn', tone: Tone.warning),
  'Matured' => (label: 'Đã đáo hạn', tone: Tone.info),
  'RedeemedAtMaturity' => (label: 'Tất toán đúng hạn', tone: Tone.neutral),
  'RedeemedEarly' => (label: 'Tất toán trước hạn', tone: Tone.neutral),
  'Cancelled' => (label: 'Đã huỷ', tone: Tone.danger),
  _ => (label: code, tone: Tone.neutral),
};

Labeled lotStatusOf(String code) => switch (code) {
  'Open' => (label: 'Đang mở', tone: Tone.success),
  'Closed' => (label: 'Đã đóng', tone: Tone.neutral),
  'SoldOut' => (label: 'Hết hạn mức', tone: Tone.warning),
  'Matured' => (label: 'Đã đáo hạn', tone: Tone.info),
  _ => (label: code, tone: Tone.neutral),
};

Labeled trxStatusOf(String code) => switch (code) {
  'Pending' => (label: 'Chờ xử lý', tone: Tone.neutral),
  'Processing' => (label: 'Đang xử lý', tone: Tone.info),
  'Success' => (label: 'Thành công', tone: Tone.success),
  'Failed' => (label: 'Thất bại', tone: Tone.danger),
  'Cancelled' => (label: 'Đã huỷ', tone: Tone.neutral),
  'PartialSuccess' => (label: 'Thành công một phần', tone: Tone.warning),
  _ => (label: code, tone: Tone.neutral),
};

String trxTypeLabel(String code) => switch (code) {
  'BuyPrimary' => 'Mua sơ cấp',
  'BuySecondary' => 'Mua',
  'SellPrimary' => 'Bán sơ cấp',
  'SellSecondary' => 'Bán / Tất toán',
  'InterestPayout' => 'Chi lãi',
  'Transfer' => 'Chuyển nhượng',
  _ => code,
};

/// Backend trả tên enum tiếng Anh ở `paymentMethodName` → mobile tự dịch từ mã.
String paymentMethodLabel(String code) => switch (code) {
  'AtMaturity' => 'Lãi cuối kỳ',
  'Monthly' => 'Lãi hàng tháng',
  'Quarterly' => 'Lãi hàng quý',
  _ => code,
};

String customerTypeLabel(String code) => switch (code) {
  'Individual' => 'Cá nhân',
  'Business' => 'Doanh nghiệp',
  _ => code,
};

String interestPeriodStatusLabel(String code) => switch (code) {
  'Paid' => 'Đã chi',
  'Upcoming' => 'Sắp đến',
  'Today' => 'Đến hạn',
  'Overdue' => 'Quá hạn',
  'Blocked' => 'Chờ kỳ trước',
  _ => code,
};

Tone interestPeriodTone(String code) => switch (code) {
  'Paid' => Tone.success,
  'Today' => Tone.warning,
  'Overdue' => Tone.danger,
  _ => Tone.neutral,
};

/// Icon tương ứng loại thông tin hiển thị nhanh (dùng chung cho thẻ tổng quan).
IconData iconForTone(Tone t) => switch (t) {
  Tone.success => Icons.check_circle_outline,
  Tone.warning => Icons.error_outline,
  Tone.danger => Icons.cancel_outlined,
  Tone.info => Icons.info_outline,
  Tone.neutral => Icons.circle_outlined,
};
