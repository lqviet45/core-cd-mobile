import '../../../core/utils/labels.dart';

/// Nhãn dành cho khách hàng (khác cách nói của nhân viên: "chi lãi" → "nhận lãi").
String custTrxTypeLabel(String code) => switch (code) {
  'BuyPrimary' || 'BuySecondary' => 'Mua CCTG',
  'SellPrimary' || 'SellSecondary' => 'Tất toán',
  'InterestPayout' => 'Nhận lãi',
  'Transfer' => 'Chuyển nhượng',
  _ => code,
};

/// Tiền vào (tất toán, nhận lãi) hay tiền ra (mua).
bool custTrxIncoming(String code) =>
    code == 'SellPrimary' ||
    code == 'SellSecondary' ||
    code == 'InterestPayout';

/// Trạng thái giao dịch bằng chữ cho khách; `null` khi thành công (không cần nhắc).
String? custTrxStatusNote(String status) => switch (status) {
  'Success' => null,
  'Pending' || 'Processing' => 'Đang xử lý',
  'Failed' => 'Không thành công',
  'Cancelled' => 'Đã huỷ',
  'PartialSuccess' => 'Thành công một phần',
  _ => status,
};

Labeled trxStatusPill(String status) => trxStatusOf(status);

String custDocumentKindLabel(String code) => switch (code) {
  'TradeContract' => 'Hợp đồng giao dịch',
  'SignedContract' => 'Hợp đồng đã ký',
  'CertificatePdf' => 'Chứng chỉ tiền gửi',
  _ => 'Tài liệu',
};

/// `1536000` → `1,5 MB` / `820 KB`.
String fileSizeLabel(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }
  return '${(bytes / 1024).ceil()} KB';
}
