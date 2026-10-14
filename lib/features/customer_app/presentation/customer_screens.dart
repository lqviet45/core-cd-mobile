import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/ui/paged_list.dart';
import '../../../core/ui/snack.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/labels.dart';
import '../../../core/utils/text.dart';
import '../data/customer_app_dto.dart';
import 'customer_documents.dart';
import 'customer_labels.dart';
import 'customer_providers.dart';

/// Tổng quan: tổng gốc đang giữ, lãi dự kiến/đã nhận, kỳ đáo hạn gần nhất.
class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(custProfileProvider);
    final summary = ref.watch(custSummaryProvider);

    Future<void> refresh() async {
      ref
        ..invalidate(custProfileProvider)
        ..invalidate(custSummaryProvider);
      try {
        await ref.read(custSummaryProvider.future);
      } on Object {
        // Lỗi đã hiển thị bởi trạng thái error của provider.
      }
    }

    final name = profile.value?.fullName;
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  header: true,
                  child: Text(
                    name == null
                        ? 'Xin chào'
                        : 'Xin chào, ${givenNameOf(name)}',
                    style: context.text.headlineSmall,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: summary.when(
              loading: () => const ListSkeleton(rows: 3),
              error: (e, _) => ErrorState(error: e, onRetry: refresh),
              data: (s) => RefreshIndicator(
                onRefresh: refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [_SummaryBody(s)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody(this.s);
  final CustomerSummary s;

  @override
  Widget build(BuildContext context) {
    if (s.holdingCount == 0) {
      return const SizedBox(
        height: 360,
        child: EmptyState(
          icon: LucideIcons.landmark,
          title: 'Bạn chưa có CCTG nào đang nắm giữ',
          message: 'Khi bạn mua chứng chỉ tiền gửi tại ngân hàng, thông tin sẽ hiển thị tại đây.',
        ),
      );
    }
    final onPrimary = AppCard.onColor(context, CardKind.primary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          kind: CardKind.primary,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tổng gốc đang nắm giữ',
                style: context.text.bodyMedium?.copyWith(color: onPrimary),
              ),
              const SizedBox(height: 4),
              MoneyText(
                s.totalPrincipal,
                style: context.text.headlineMedium?.copyWith(
                  color: onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${s.holdingCount} chứng chỉ',
                style: context.text.bodyMedium?.copyWith(color: onPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SummaryCard(
          rows: [
            (
              'Lãi dự kiến theo hợp đồng',
              formatMoney(s.estimatedInterestTotal),
            ),
            ('Lãi đã nhận', formatMoney(s.interestReceivedTotal)),
          ],
        ),
        if (s.nextMaturityDate != null) ...[
          const SizedBox(height: 12),
          AppCard(
            kind: CardKind.primaryContainer,
            onTap: s.nextMaturityCertificateId == null
                ? null
                : () => context.push(
                    '/certificates/${s.nextMaturityCertificateId}',
                  ),
            child: Row(
              children: [
                const Icon(LucideIcons.calendarClock),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đáo hạn gần nhất', style: context.text.bodySmall),
                      Text(
                        '${formatDate(s.nextMaturityDate)} · ${formatDaysFrom(s.nextMaturityDate!, DateTime.now())}',
                        style: context.text.titleMedium,
                      ),
                      if (s.nextMaturityCertificateNumber != null)
                        Text(
                          s.nextMaturityCertificateNumber!,
                          style: context.text.bodySmall,
                        ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 20),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── CCTG ────────────────────────────────────────────────────────────
class CustomerCertificatesScreen extends ConsumerWidget {
  const CustomerCertificatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(custCertScopeProvider);
    final state = ref.watch(custCertificatesProvider);
    final notifier = ref.read(custCertificatesProvider.notifier);
    return Scaffold(
      body: Column(
        children: [
          const BigHeader('Chứng chỉ của tôi'),
          FilterChipsRow<String>(
            options: const [('Holding', 'Đang giữ'), ('Closed', 'Đã đóng')],
            value: scope,
            onChanged: (v) => ref.read(custCertScopeProvider.notifier).set(v),
          ),
          Expanded(
            child: PagedListView<CustCertificate>(
              state: state,
              onRefresh: notifier.refresh,
              onLoadMore: notifier.loadMore,
              emptyTitle: scope == 'Holding'
                  ? 'Bạn chưa có CCTG đang nắm giữ'
                  : 'Chưa có CCTG đã đóng',
              itemBuilder: (context, c) => _CertificateCard(c),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard(this.c);
  final CustCertificate c;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    return AppCard(
      kind: CardKind.outlined,
      onTap: () => context.push('/certificates/${c.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.certificateNumber,
                  style: context.text.titleMedium,
                ),
              ),
              StatusChip(certStatusOf(c.status)),
            ],
          ),
          const SizedBox(height: 8),
          MoneyText(
            c.principal,
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${c.termName} · ${formatPercent(c.annualRatePercent)}/năm · ${paymentMethodLabel(c.paymentMethod)}',
            style: context.text.bodyMedium?.copyWith(color: s.onSurfaceVariant),
          ),
          Text(
            'Đáo hạn ${formatDate(c.maturityDate)}',
            style: context.text.bodyMedium?.copyWith(color: s.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class CustomerCertificateDetailScreen extends ConsumerWidget {
  const CustomerCertificateDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cert = ref.watch(custCertificateProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết CCTG')),
      body: cert.when(
        loading: () => const ListSkeleton(rows: 3),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(custCertificateProvider(id)),
        ),
        data: (c) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(custCertificateProvider(id))
              ..invalidate(custScheduleProvider(id));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.certificateNumber,
                      style: context.text.titleLarge,
                    ),
                  ),
                  StatusChip(certStatusOf(c.status)),
                ],
              ),
              const SizedBox(height: 12),
              ListGroup(
                children: [
                  InfoRow('Số tiền gốc', formatMoney(c.principal)),
                  InfoRow('Kỳ hạn', '${c.termName} (${c.termDays} ngày)'),
                  InfoRow(
                    'Lãi suất',
                    '${formatPercent(c.annualRatePercent)}/năm',
                  ),
                  InfoRow(
                    'Hình thức nhận lãi',
                    paymentMethodLabel(c.paymentMethod),
                  ),
                  InfoRow('Ngày phát hành', formatDate(c.issueDate)),
                  InfoRow('Ngày đáo hạn', formatDate(c.maturityDate)),
                  InfoRow(
                    'Lãi theo hợp đồng',
                    formatMoney(c.estimatedInterest),
                  ),
                  InfoRow('Lãi đã nhận', formatMoney(c.totalInterestPaid)),
                  if (c.redemptionDate != null)
                    InfoRow('Ngày tất toán', formatDate(c.redemptionDate)),
                  if (c.netAmountAtRedemption != null)
                    InfoRow(
                      'Số tiền nhận khi tất toán',
                      formatMoney(c.netAmountAtRedemption),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _Schedule(id: id),
              const SizedBox(height: 16),
              CustDocumentsSection(ownerType: 'certificates', ownerId: id),
            ],
          ),
        ),
      ),
    );
  }
}

class _Schedule extends ConsumerWidget {
  const _Schedule({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sched = ref.watch(custScheduleProvider(id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Lịch nhận lãi'),
        const SizedBox(height: 8),
        sched.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(custScheduleProvider(id)),
          ),
          data: (s) => s.periods.isEmpty
              ? NoteCard(
                  icon: LucideIcons.calendarCheck,
                  kind: CardKind.outlined,
                  text: Text(
                    'Lãi trả một lần khi đáo hạn: ${formatMoney(s.contractInterest)}.',
                  ),
                )
              : ListGroup(
                  children: [
                    for (final p in s.periods)
                      ListRow(
                        title:
                            'Kỳ ${p.index}/${p.total} · ${formatMoney(p.amount)}',
                        subtitle:
                            '${formatDate(p.start)} → ${formatDate(p.end)}'
                            '${p.paidDate == null ? '' : ' · nhận ${formatDate(p.paidDate)}'}',
                        trailing: StatusChip(custPeriodStatusOf(p.status)),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── Giao dịch ───────────────────────────────────────────────────────
class CustomerTransactionsScreen extends ConsumerWidget {
  const CustomerTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(custTransactionsProvider);
    final notifier = ref.read(custTransactionsProvider.notifier);
    return Scaffold(
      body: Column(
        children: [
          const BigHeader('Giao dịch'),
          Expanded(
            child: PagedListView<CustTransaction>(
              state: state,
              onRefresh: notifier.refresh,
              onLoadMore: notifier.loadMore,
              emptyTitle: 'Chưa có giao dịch',
              itemBuilder: (context, t) => AppCard(
                kind: CardKind.outlined,
                onTap: () => context.push('/transactions/${t.id}'),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            custTrxTypeLabel(t.type),
                            style: context.text.titleMedium,
                          ),
                          Text(
                            '${t.trxNo} · ${formatDateTime(t.createdAt)}',
                            style: context.text.bodySmall?.copyWith(
                              color: context.scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        MoneyText(t.amount, style: context.text.titleMedium),
                        const SizedBox(height: 4),
                        StatusChip(trxStatusOf(t.status)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerTransactionDetailScreen extends ConsumerWidget {
  const CustomerTransactionDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trx = ref.watch(custTransactionProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết giao dịch')),
      body: trx.when(
        loading: () => const ListSkeleton(rows: 3),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(custTransactionProvider(id)),
        ),
        data: (t) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ListGroup(
              children: [
                InfoRow('Loại giao dịch', custTrxTypeLabel(t.type)),
                InfoRow('Mã giao dịch', t.trxNo, mono: true),
                InfoRow('Số tiền', formatMoney(t.amount)),
                InfoRow(
                  'Trạng thái',
                  null,
                  valueWidget: StatusChip(trxStatusOf(t.status)),
                ),
                InfoRow('Thời gian', formatDateTime(t.createdAt)),
                if (t.contractCode != null)
                  InfoRow('Mã hợp đồng', t.contractCode, mono: true),
              ],
            ),
            if (t.status == 'Failed') ...[
              const SizedBox(height: 12),
              const NoteCard(
                kind: CardKind.error,
                text: Text(
                  'Giao dịch không thành công. Vui lòng liên hệ ngân hàng để được hỗ trợ.',
                ),
              ),
            ],
            const SizedBox(height: 16),
            CustDocumentsSection(ownerType: 'transactions', ownerId: id),
          ],
        ),
      ),
    );
  }
}

// ── Tài khoản ───────────────────────────────────────────────────────
class CustomerAccountScreen extends ConsumerWidget {
  const CustomerAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(custProfileProvider);
    return Scaffold(
      body: Column(
        children: [
          const BigHeader('Tài khoản'),
          Expanded(
            child: profile.when(
              loading: () => const ListSkeleton(rows: 3),
              error: (e, _) => ErrorState(
                error: e,
                onRetry: () => ref.invalidate(custProfileProvider),
              ),
              data: (p) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  ListGroup(
                    children: [
                      InfoRow('Họ tên', p.fullName),
                      InfoRow('Mã khách hàng (CIF)', p.cif, mono: true),
                      InfoRow(
                        'Loại khách hàng',
                        customerTypeLabel(p.customerType),
                      ),
                      InfoRow('CCCD / MST', p.identityNumberMasked, mono: true),
                      InfoRow('Số điện thoại', p.phoneMasked, mono: true),
                      InfoRow('Email', p.email),
                      if (p.address != null) InfoRow('Địa chỉ', p.address),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const NoteCard(
                    kind: CardKind.outlined,
                    text: Text(
                      'Để thay đổi thông tin cá nhân hoặc số điện thoại nhận OTP, vui lòng đến chi nhánh ngân hàng.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context, ref),
                    icon: const Icon(LucideIcons.logOut),
                    label: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ cần mã OTP để đăng nhập lại.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(custAuthControllerProvider.notifier).logout();
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message, error: true);
    }
  }
}
