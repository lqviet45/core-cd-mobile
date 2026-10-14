import '../../../core/utils/labels.dart';

/// Nhãn dành cho khách hàng (khác cách nói của nhân viên: "chi lãi" → "nhận lãi").
String custTrxTypeLabel(String code) => switch (code) {
  'BuyPrimary' || 'BuySecondary' => 'Mua CCTG',
  'SellPrimary' || 'SellSecondary' => 'Tất toán / Bán',
  'InterestPayout' => 'Nhận lãi',
  'Transfer' => 'Chuyển nhượng',
  _ => code,
};

Labeled custPeriodStatusOf(String code) => switch (code) {
  'Paid' => (label: 'Đã nhận', tone: Tone.success),
  'Due' => (label: 'Đến kỳ', tone: Tone.warning),
  _ => (label: 'Sắp đến', tone: Tone.neutral),
};

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
