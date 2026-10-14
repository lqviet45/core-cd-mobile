import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/models/paged.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/ui/paged_list.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../data/admin_dto.dart';
import 'admin_common.dart';

/// Tên lệnh nghiệp vụ → nhãn tiếng Việt; lệnh lạ hiện dạng tách chữ (`BuyCertificate` → `Buy Certificate`).
String auditActionLabel(String action) => switch (action) {
  'BuyCertificate' => 'Mua CCTG',
  'SellCertificates' => 'Bán CCTG',
  'IssueCertificate' => 'Phát hành CCTG',
  'RedeemEarly' => 'Tất toán trước hạn',
  'RedeemAtMaturity' => 'Tất toán đúng hạn',
  'BulkRedeem' => 'Tất toán hàng loạt',
  'BulkPayInterest' => 'Chi lãi hàng loạt',
  'PayInterest' => 'Chi lãi',
  'CreateCustomer' => 'Tạo khách hàng',
  'OpenCdLot' => 'Mở đợt phát hành',
  'CloseCdLot' => 'Đóng đợt phát hành',
  'CreateUser' => 'Tạo người dùng',
  'UpdateUser' => 'Sửa người dùng',
  'ResetUserPassword' => 'Đặt lại mật khẩu',
  'UpdateNotificationPreferences' => 'Đổi cài đặt thông báo',
  'RetryTransaction' => 'Tạo lại giao dịch',
  _ => action.replaceAllMapped(RegExp('(?<=[a-z])(?=[A-Z])'), (_) => ' '),
};

enum AuditRange { all, today, week }

class AuditQuery {
  const AuditQuery({this.range = AuditRange.all, this.user = ''});
  final AuditRange range;
  final String user;
  AuditQuery copyWith({AuditRange? range, String? user}) =>
      AuditQuery(range: range ?? this.range, user: user ?? this.user);
}

class AuditQueryNotifier extends Notifier<AuditQuery> {
  @override
  AuditQuery build() => const AuditQuery();

  // ignore: use_setters_to_change_properties
  void set(AuditQuery q) => state = q;
}

final auditQueryProvider = NotifierProvider<AuditQueryNotifier, AuditQuery>(
  AuditQueryNotifier.new,
);

class AuditNotifier extends PagedNotifier<AuditLogEntry> {
  @override
  PagedState<AuditLogEntry> build() {
    ref.watch(auditQueryProvider);
    return super.build();
  }

  @override
  Future<Paged<AuditLogEntry>> fetch(int page) {
    final q = ref.read(auditQueryProvider);
    final now = DateTime.now();
    final from = switch (q.range) {
      AuditRange.all => null,
      AuditRange.today => DateTime(now.year, now.month, now.day),
      AuditRange.week => now.subtract(const Duration(days: 7)),
    };
    return ref
        .read(adminRepositoryProvider)
        .auditLogs(page: page, userName: q.user, from: from);
  }
}

final auditProvider =
    NotifierProvider<AuditNotifier, PagedState<AuditLogEntry>>(
      AuditNotifier.new,
    );

/// Payload JSON → dạng thụt lề dễ đọc; không phải JSON thì giữ nguyên.
String prettyPayload(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
  } on FormatException {
    return raw;
  }
}

/// Nhật ký thao tác (chỉ Admin, chỉ đọc).
class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  // Chỉ dựng thân màn (và tải dữ liệu) khi là Admin.
  @override
  Widget build(BuildContext context) =>
      const AdminOnly(title: 'Nhật ký thao tác', child: _AuditBody());
}

class _AuditBody extends ConsumerStatefulWidget {
  const _AuditBody();

  @override
  ConsumerState<_AuditBody> createState() => _AuditBodyState();
}

class _AuditBodyState extends ConsumerState<_AuditBody> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => ref
          .read(auditQueryProvider.notifier)
          .set(ref.read(auditQueryProvider).copyWith(user: v.trim())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auditProvider);
    final query = ref.watch(auditQueryProvider);
    final notifier = ref.read(auditProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Nhật ký thao tác')),
      body: Column(
        children: [
          SearchField(
            hint: 'Tên đăng nhập người thao tác',
            onChanged: _onSearch,
          ),
          FilterChipsRow<AuditRange>(
            options: const [
              (AuditRange.all, 'Tất cả'),
              (AuditRange.today, 'Hôm nay'),
              (AuditRange.week, '7 ngày'),
            ],
            value: query.range,
            onChanged: (v) => ref
                .read(auditQueryProvider.notifier)
                .set(query.copyWith(range: v)),
          ),
          Expanded(
            child: PagedListView<AuditLogEntry>(
              state: state,
              onRefresh: notifier.refresh,
              onLoadMore: notifier.loadMore,
              emptyTitle: 'Chưa có thao tác nào',
              emptyMessage: 'Thử đổi khoảng thời gian hoặc người thao tác.',
              separatorHeight: 8,
              itemBuilder: (context, a) => ListGroup(
                children: [
                  ListRow(
                    lead: const Lead(square: true, icon: LucideIcons.history),
                    title: auditActionLabel(a.action),
                    subtitle: '${a.userName} · ${formatDateTime(a.createdAt)}',
                    chevron: true,
                    onTap: () => showAdminSheet<void>(context, _AuditDetail(a)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditDetail extends StatelessWidget {
  const _AuditDetail(this.a);
  final AuditLogEntry a;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(auditActionLabel(a.action), style: context.text.titleLarge),
      const SizedBox(height: 12),
      ListGroup(
        children: [
          InfoRow('Lệnh', a.action, mono: true),
          InfoRow(
            'Người thao tác',
            '${a.userName}${a.role == null ? '' : ' · ${a.role}'}',
          ),
          InfoRow('Thời điểm', formatDateTime(a.createdAt)),
          InfoRow('Địa chỉ IP', a.ipAddress),
          InfoRow('Mã vết', a.traceId, mono: true),
        ],
      ),
      const SizedBox(height: 12),
      Text('Nội dung lệnh', style: context.text.labelLarge),
      const SizedBox(height: 4),
      Text(
        'Dữ liệu nhạy cảm đã được che ở máy chủ.',
        style: context.text.bodySmall?.copyWith(
          color: context.scheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      AppCard(
        kind: CardKind.outlined,
        child: SelectableText(
          prettyPayload(a.payload),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
        ),
      ),
    ],
  );
}
