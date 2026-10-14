import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/format.dart';
import '../data/customer_app_dto.dart';
import 'kh_format.dart';
import 'kh_theme.dart';
import 'kh_widgets.dart';

/// Nhãn trạng thái CCTG của khách: `(chữ, kiểu nhãn)`.
(String, KhPillKind) khCertPill(String status) => switch (status) {
  'Active' => ('Đang gửi', KhPillKind.primary),
  'NearMaturity' => ('Sắp đáo hạn', KhPillKind.soon),
  'Matured' => ('Đã đến hạn', KhPillKind.soon),
  'RedeemedAtMaturity' || 'RedeemedEarly' => ('Đã tất toán', KhPillKind.done),
  'Cancelled' => ('Đã huỷ', KhPillKind.done),
  _ => (status, KhPillKind.done),
};

bool khIsSoon(String status) => status == 'NearMaturity' || status == 'Matured';

String khReceiptTitle(CustReceipt r) {
  if (r.isMaturity) return 'Đáo hạn ${khTerm(r.termName)}';
  return r.paymentMethod == 'Quarterly' ? 'Nhận lãi quý' : 'Nhận lãi tháng';
}

/// Dòng "Sắp tới"/"Lịch nhận tiền": ô ngày (hổ phách khi đáo hạn ≤ 7 ngày hoặc đã đến kỳ), tên khoản, số tiền vào.
class KhReceiptRow extends StatelessWidget {
  const KhReceiptRow(this.r, {super.key, this.detailed = false});
  final CustReceipt r;

  /// true (màn Lịch): phụ đề mô tả khoản; false (Trang chủ): đếm ngược.
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final days = khDaysUntil(r.date, DateTime.now());
    final soon = r.isDue || (r.isMaturity && days <= 7);
    final String sub;
    if (r.isMaturity) {
      sub = detailed
          ? (r.paymentMethod == 'AtMaturity'
                ? 'Gồm gốc và lãi cuối kỳ'
                : 'Hoàn gốc')
          : khCountdown(days);
    } else {
      sub = 'Kỳ ${r.periodIndex}/${r.periodTotal} · ${khTerm(r.termName)}';
    }
    return KhRow(
      leading: KhDateBadge(r.date, soon: soon),
      title: khReceiptTitle(r),
      subtitle: r.isDue && !r.isMaturity ? '$sub · đã đến kỳ' : sub,
      minHeight: detailed ? 72 : 60,
      trailing: Text(
        khSignedCompact(r.amount),
        style: KhType.b.copyWith(
          color: context.kh.ok,
          fontWeight: FontWeight.w600,
          fontFeatures: KhType.nums,
        ),
      ),
      onTap: () => context.push('/certificate/${r.certificateId}'),
    );
  }
}

/// Dòng CCTG gọn ở Trang chủ.
class KhCertRow extends StatelessWidget {
  const KhCertRow(this.c, {super.key});
  final CustCertificate c;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    return KhRow(
      leading: KhIconTile(
        LucideIcons.fileText,
        tone: khIsSoon(c.status) ? KhTone.amber : KhTone.primary,
      ),
      title: '${khTerm(c.termName)} · ${khPercent(c.annualRatePercent)}',
      subtitle: 'Đáo hạn ${formatDate(c.maturityDate)}',
      trailing: Text(
        khCompact(c.principal),
        style: KhType.b.copyWith(
          color: k.ink,
          fontWeight: FontWeight.w600,
          fontFeatures: KhType.nums,
        ),
      ),
      onTap: () => context.push('/certificate/${c.id}'),
    );
  }
}

/// Thẻ CCTG trong danh sách (K03).
class KhCertCard extends StatelessWidget {
  const KhCertCard(this.c, {super.key});
  final CustCertificate c;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    final (label, kind) = khCertPill(c.status);
    final closed = !c.isHolding;
    final soon = khIsSoon(c.status);
    final now = DateTime.now();
    final days = khDaysUntil(c.maturityDate, now);
    return KhCard(
      transparent: closed,
      borderColor: soon ? k.ambBar : null,
      onTap: () => context.push('/certificate/${c.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.certificateNumber,
                  style: KhType.code.copyWith(
                    color: k.ink3,
                    fontFeatures: KhType.nums,
                  ),
                ),
              ),
              KhPill(label, kind: kind),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      khTerm(c.termName),
                      style: KhType.t2.copyWith(color: k.ink),
                    ),
                    Text(
                      '${khPercent(c.annualRatePercent)}/năm · ${khMethodLong(c.paymentMethod)}',
                      style: KhType.s.copyWith(color: k.ink2),
                    ),
                  ],
                ),
              ),
              Text(
                khCompact(c.principal),
                style: TextStyle(
                  fontSize: closed ? 17 : 22,
                  height: 28 / 22,
                  fontWeight: closed ? FontWeight.w500 : FontWeight.w600,
                  color: closed ? k.ink3 : k.ink,
                  fontFeatures: KhType.nums,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (closed)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Tất toán ${formatDate(c.redemptionDate)}'),
                  if (c.netAmountAtRedemption != null) ...[
                    const TextSpan(text: ' · đã nhận '),
                    TextSpan(
                      text: formatMoney(c.netAmountAtRedemption),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: k.ink,
                        fontFeatures: KhType.nums,
                      ),
                    ),
                  ],
                ],
              ),
              style: KhType.s.copyWith(color: k.ink2),
            )
          else ...[
            KhBar(khProgress(c.issueDate, c.maturityDate, now), soon: soon),
            KhMeta(
              left: formatDate(c.issueDate),
              center: khCountdown(days),
              right: formatDate(c.maturityDate),
              soon: soon,
            ),
          ],
        ],
      ),
    );
  }
}
