import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/models/paged.dart';
import '../../../core/money/money_gate.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/ui/paged_list.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/labels.dart';
import '../../../core/utils/text.dart';
import '../../certificates/presentation/certificate_providers.dart';
import '../data/customer_dto.dart';

class CustomerQuery {
  const CustomerQuery({this.type = '', this.search = ''});
  final String type;
  final String search;
  CustomerQuery copyWith({String? type, String? search}) =>
      CustomerQuery(type: type ?? this.type, search: search ?? this.search);
}

class CustomerQueryNotifier extends Notifier<CustomerQuery> {
  @override
  CustomerQuery build() => const CustomerQuery();

  // ignore: use_setters_to_change_properties
  void set(CustomerQuery q) => state = q;
}

final customerQueryProvider =
    NotifierProvider<CustomerQueryNotifier, CustomerQuery>(
      CustomerQueryNotifier.new,
    );

class CustomersNotifier extends PagedNotifier<Customer> {
  @override
  PagedState<Customer> build() {
    ref.watch(customerQueryProvider);
    return super.build();
  }

  @override
  Future<Paged<Customer>> fetch(int page) {
    final q = ref.read(customerQueryProvider);
    return ref
        .read(customerRepositoryProvider)
        .list(page: page, search: q.search, customerType: q.type);
  }
}

final customersProvider =
    NotifierProvider<CustomersNotifier, PagedState<Customer>>(
      CustomersNotifier.new,
    );

final customerProvider = FutureProvider.autoDispose.family<Customer, String>(
  (ref, id) => ref.watch(customerRepositoryProvider).get(id),
);

/// M10 – Danh sách khách hàng.
class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = ref.read(customerQueryProvider);
      ref
          .read(customerQueryProvider.notifier)
          .set(q.copyWith(search: v.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customersProvider);
    final query = ref.watch(customerQueryProvider);
    final notifier = ref.read(customersProvider.notifier);

    return Scaffold(
      body: Column(
        children: [
          BigHeader(
            'Khách hàng',
            actions: [
              if (ref.watch(canWriteProvider))
                IconBtn(
                  icon: LucideIcons.userPlus,
                  label: 'Thêm khách hàng',
                  onPressed: () => context.push('/customers/new'),
                ),
            ],
          ),
          SearchField(hint: 'Tên, CIF, CCCD/MST, SĐT', onChanged: _onSearch),
          FilterChipsRow<String>(
            options: const [
              ('', 'Tất cả'),
              ('Individual', 'Cá nhân'),
              ('Business', 'Doanh nghiệp'),
            ],
            value: query.type,
            onChanged: (v) => ref
                .read(customerQueryProvider.notifier)
                .set(query.copyWith(type: v)),
          ),
          Expanded(
            child: PagedListView<Customer>(
              state: state,
              onRefresh: notifier.refresh,
              onLoadMore: notifier.loadMore,
              emptyTitle: 'Không có khách hàng phù hợp',
              emptyMessage: 'Thử đổi bộ lọc hoặc từ khoá tìm kiếm.',
              separatorHeight: 0,
              // Nhóm hàng liền khối như `.m-list`: bo góc ở thẻ ngoài, đường kẻ giữa các hàng.
              itemBuilder: (context, c) => _CustomerRow(c),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow(this.c);
  final Customer c;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      decoration: BoxDecoration(
        color: s.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: s.outlineVariant)),
      ),
      child: ListRow(
        lead: c.isBusiness
            ? const Lead(square: true, icon: LucideIcons.building2)
            : Lead(text: initialsOf(c.fullName)),
        title: c.fullName,
        subtitle: c.isActive
            ? '${c.cif} · ${c.totalCertificates} CCTG'
            : '${c.cif} · Vô hiệu',
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              c.isActive ? '${formatCompact(c.outstandingPrincipal)} ₫' : '0',
              style: context.text.titleSmall,
            ),
            Text(
              'dư nợ',
              style: context.text.bodySmall?.copyWith(
                color: s.onSurfaceVariant,
              ),
            ),
          ],
        ),
        onTap: () => context.push('/customers/${c.id}'),
      ),
    );
  }
}

/// M11 – Chi tiết khách hàng.
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cust = ref.watch(customerProvider(id));
    final certs = ref.watch(customerCertificatesProvider(id));
    return Scaffold(
      appBar: AppBar(),
      body: cust.when(
        loading: () => const ListSkeleton(rows: 3),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(customerProvider(id)),
        ),
        data: (c) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(customerProvider(id))
              ..invalidate(customerCertificatesProvider(id));
            await ref.read(customerProvider(id).future).catchError((_) => c);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: FittedBox(
                      child: c.isBusiness
                          ? const Lead(
                              square: true,
                              icon: LucideIcons.building2,
                            )
                          : Lead(text: initialsOf(c.fullName)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.fullName, style: context.text.titleLarge),
                        Text(
                          '${c.cif} · ${customerTypeLabel(c.customerType)}',
                          style: context.text.bodyMedium?.copyWith(
                            color: context.scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!c.isActive)
                    const StatusChip((label: 'Vô hiệu', tone: Tone.neutral)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      'Dư nợ gốc',
                      '${formatCompact(c.outstandingPrincipal)} ₫',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Stat('CCTG', formatInt(c.totalCertificates)),
                  ),
                ],
              ),
              if (ref.watch(canWriteProvider) && c.isActive) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            context.push('/trade/buy?customerId=${c.id}'),
                        icon: const Icon(LucideIcons.download, size: 18),
                        label: const Text('Mua CCTG'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/trade/sell?customerId=${c.id}'),
                        icon: const Icon(LucideIcons.upload, size: 18),
                        label: const Text('Bán / Tất toán'),
                      ),
                    ),
                  ],
                ),
              ],
              const SectionHeader('Thông tin'),
              const SizedBox(height: 8),
              ListGroup(
                children: [
                  InfoRow(
                    c.isBusiness ? 'Mã số thuế' : 'CCCD / CMND',
                    c.identityNumber,
                    mono: true,
                  ),
                  InfoRow('Điện thoại', c.phone),
                  InfoRow('Email', c.email),
                  if (c.address != null && c.address!.isNotEmpty)
                    InfoRow('Địa chỉ', c.address),
                  if (c.isBusiness) ...[
                    InfoRow('Số ĐKKD', c.businessRegistrationNumber),
                    InfoRow(
                      'Người đại diện',
                      c.representativeName == null
                          ? null
                          : '${c.representativeName}${c.representativeTitle == null ? '' : ' (${c.representativeTitle})'}',
                    ),
                  ],
                  InfoRow('Ngày tạo', formatDate(c.createdAt)),
                ],
              ),
              const SectionHeader('Chứng chỉ gần đây'),
              const SizedBox(height: 8),
              certs.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => AppCard(
                  kind: CardKind.outlined,
                  child: Text(
                    'Không tải được danh sách CCTG.',
                    style: TextStyle(color: context.scheme.error),
                  ),
                ),
                data: (page) => page.items.isEmpty
                    ? const AppCard(
                        kind: CardKind.outlined,
                        child: Text('Khách hàng chưa có CCTG.'),
                      )
                    : ListGroup(
                        children: [
                          for (final x in page.items.take(10))
                            ListRow(
                              lead: Lead(
                                square: true,
                                icon: LucideIcons.fileText,
                                kind: x.status == 'NearMaturity'
                                    ? LeadKind.warn
                                    : LeadKind.primary,
                              ),
                              title: x.certificateNumber,
                              subtitle: x.isRedeemed
                                  ? certStatusOf(x.status).label
                                  : 'Đáo hạn ${formatDate(x.maturityDate)}',
                              trailing: Text(
                                '${formatCompact(x.principal)} ₫',
                                style: context.text.titleMedium,
                              ),
                              onTap: () =>
                                  context.push('/certificates/${x.id}'),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.bodySmall?.copyWith(
            color: context.scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: context.text.titleLarge),
      ],
    ),
  );
}
