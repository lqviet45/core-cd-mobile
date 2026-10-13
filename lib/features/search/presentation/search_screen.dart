import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/labels.dart';
import '../../../core/utils/text.dart';
import 'search_providers.dart';

enum _Scope { all, customers, certs, trx }

/// M27 – Tìm kiếm toàn cục: khách hàng · CCTG · giao dịch theo CIF.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _term = '';
  _Scope _scope = _Scope.all;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => setState(() => _term = v.trim()),
    );
    setState(() {}); // cập nhật nút xoá
  }

  void _useTerm(String t) {
    _controller.text = t;
    _debounce?.cancel();
    setState(() => _term = t);
  }

  Future<void> _open(String route) async {
    await ref.read(searchHistoryProvider.notifier).add(_term);
    // `go`, không `push`: /search nằm ngoài shell nên push một route của shell sẽ trùng khoá trang với shell đang có.
    if (mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    final history = ref.watch(searchHistoryProvider);
    final searching = _term.length >= 2;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconBtn(
                    icon: LucideIcons.chevronLeft,
                    label: 'Quay lại',
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: _onChanged,
                      onSubmitted: (v) {
                        _debounce?.cancel();
                        setState(() => _term = v.trim());
                      },
                      decoration: InputDecoration(
                        hintText: 'Tên, CIF, số CCTG…',
                        filled: true,
                        fillColor: s.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Xoá',
                                icon: const Icon(LucideIcons.x, size: 20),
                                onPressed: () {
                                  _controller.clear();
                                  _useTerm('');
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (searching)
              FilterChipsRow<_Scope>(
                options: const [
                  (_Scope.all, 'Tất cả'),
                  (_Scope.customers, 'Khách hàng'),
                  (_Scope.certs, 'CCTG'),
                  (_Scope.trx, 'Giao dịch'),
                ],
                value: _scope,
                onChanged: (v) => setState(() => _scope = v),
              ),
            Expanded(
              child: searching
                  ? _Results(term: _term, scope: _scope, onOpen: _open)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        if (history.isEmpty)
                          const EmptyState(
                            title: 'Tìm khách hàng, CCTG, giao dịch',
                            message: 'Nhập ít nhất 2 ký tự. Tìm giao dịch bằng mã CIF.',
                            icon: LucideIcons.search,
                          )
                        else ...[
                          SectionHeader(
                            'Gần đây',
                            actionLabel: 'Xoá',
                            onAction: () => ref
                                .read(searchHistoryProvider.notifier)
                                .clear(),
                          ),
                          const SizedBox(height: 8),
                          ListGroup(
                            children: [
                              for (final h in history)
                                ListRow(
                                  lead: const Lead(
                                    square: true,
                                    icon: LucideIcons.history,
                                  ),
                                  title: h,
                                  onTap: () => _useTerm(h),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.term,
    required this.scope,
    required this.onOpen,
  });
  final String term;
  final _Scope scope;
  final Future<void> Function(String route) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = ref.watch(searchResultsProvider(term));
    return res.when(
      loading: () => const ListSkeleton(rows: 4),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(searchResultsProvider(term)),
      ),
      data: (r) {
        final showC = scope == _Scope.all || scope == _Scope.customers;
        final showK = scope == _Scope.all || scope == _Scope.certs;
        final showT = scope == _Scope.all || scope == _Scope.trx;
        final empty =
            (!showC || r.customers.isEmpty) &&
            (!showK || r.certificates.isEmpty) &&
            (!showT || r.transactions.isEmpty);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            if (r.failed.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NoteCard(
                  icon: LucideIcons.triangleAlert,
                  text: Text(
                    'Không tìm được: ${r.failed.join(', ')}. Kết quả khác vẫn hiển thị.',
                  ),
                ),
              ),
            if (empty && r.failed.isEmpty)
              const EmptyState(
                title: 'Không có kết quả',
                message: 'Thử từ khoá khác hoặc kiểm tra chính tả.',
                icon: LucideIcons.searchX,
              ),
            if (showC && r.customers.isNotEmpty) ...[
              const SectionHeader('Khách hàng'),
              const SizedBox(height: 8),
              ListGroup(
                children: [
                  for (final c in r.customers)
                    ListRow(
                      lead: c.isBusiness
                          ? const Lead(
                              square: true,
                              icon: LucideIcons.building2,
                            )
                          : Lead(text: initialsOf(c.fullName)),
                      title: c.fullName,
                      subtitle: '${c.cif} · ${c.totalCertificates} CCTG',
                      chevron: true,
                      onTap: () => onOpen('/customers/${c.id}'),
                    ),
                ],
              ),
            ],
            if (showK && r.certificates.isNotEmpty) ...[
              const SectionHeader('Chứng chỉ'),
              const SizedBox(height: 8),
              ListGroup(
                children: [
                  for (final c in r.certificates)
                    ListRow(
                      lead: const Lead(
                        square: true,
                        icon: LucideIcons.fileText,
                      ),
                      title: c.certificateNumber,
                      subtitle:
                          '${c.customerName} · ${formatCompact(c.principal)} ₫',
                      trailing: StatusChip(certStatusOf(c.status)),
                      onTap: () => onOpen('/certificates/${c.id}'),
                    ),
                ],
              ),
            ],
            if (showT && r.transactions.isNotEmpty) ...[
              const SectionHeader('Giao dịch'),
              const SizedBox(height: 8),
              ListGroup(
                children: [
                  for (final t in r.transactions)
                    ListRow(
                      lead: const Lead(square: true, icon: LucideIcons.repeat),
                      title: '${trxTypeLabel(t.type)} · ${t.cif}',
                      subtitle: '${t.trxNo} · ${formatCompact(t.amount)} ₫',
                      trailing: StatusChip(trxStatusOf(t.status)),
                      onTap: () => onOpen('/transactions/${t.id}'),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
