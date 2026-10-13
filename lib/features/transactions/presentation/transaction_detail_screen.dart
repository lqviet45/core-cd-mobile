import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/money/money_action.dart';
import '../../../core/money/money_gate.dart';
import '../../../core/ui/snack.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/labels.dart';
import '../../dashboard/data/dashboard_dto.dart';
import '../../trading/presentation/trading_providers.dart';

enum _StepState { done, active, fail, wait }

_StepState _stepOf(String s) => switch (s) {
  'Success' => _StepState.done,
  'Failed' || 'Cancelled' => _StepState.fail,
  'Processing' => _StepState.active,
  _ => _StepState.wait,
};

/// M16 – Theo dõi giao dịch. Tự cập nhật mỗi 1,5 giây cho tới khi giao dịch kết thúc.
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch = ref.watch(transactionWatchProvider(id));
    return Scaffold(
      appBar: AppBar(
        leading: IconBtn(
          icon: LucideIcons.chevronLeft,
          label: 'Quay lại',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/transactions'),
        ),
        title: const Text('Theo dõi giao dịch'),
      ),
      body: watch.when(
        loading: () => const ListSkeleton(rows: 4),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(transactionWatchProvider(id)),
        ),
        data: (t) => _Body(t: t),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.t});
  final Transaction t;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  Future<void> _retry() async {
    if (_busy) return;
    final t = widget.t;
    setState(() => _busy = true);
    final created = await runMoneyAction(
      context,
      ref,
      reason: 'Xác nhận tạo lại lệnh ${t.trxNo}',
      action: () => ref.read(transactionRepositoryProvider).retry(t.id),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (created != null) {
      showSnack(context, 'Đã tạo lại lệnh');
      context.go('/transactions/${created.transactionId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final s = context.scheme;
    final tones = context.tones;
    final isSell = t.type.startsWith('Sell');
    final verb = isSell ? 'Bán / tất toán' : 'Mua CCTG';
    final ok = t.status == 'Success';
    final failed = t.status == 'Failed' || t.status == 'Cancelled';
    final partial = t.status == 'PartialSuccess';
    final canRetry =
        failed &&
        ref.watch(canWriteProvider) &&
        t.retriedByTransactionId == null;

    final (bg, fg, icon, title) = ok
        ? (tones.okContainer, tones.onOk, LucideIcons.check, '$verb thành công')
        : failed
        ? (tones.errorContainer, tones.onError, LucideIcons.x, '$verb thất bại')
        : partial
        ? (
            tones.warnContainer,
            tones.onWarn,
            LucideIcons.triangleAlert,
            '$verb thành công một phần',
          )
        : (
            tones.infoContainer,
            tones.onInfo,
            LucideIcons.loader,
            '$verb đang xử lý',
          );

    final steps = <(String, String?, _StepState)>[
      ('Đã tiếp nhận lệnh', formatDateTime(t.createdAt), _StepState.done),
      ('Bút toán tiền', null, _stepOf(t.fundTransferStatus)),
      ('Bút toán CCTG', null, _stepOf(t.cdTransferStatus)),
      (
        ok
            ? 'Hoàn tất'
            : t.isTerminal
            ? 'Kết thúc với lỗi'
            : 'Kết quả',
        t.updatedAt != null && t.isTerminal
            ? formatDateTime(t.updatedAt)
            : null,
        ok
            ? _StepState.done
            : t.isTerminal
            ? _StepState.fail
            : _StepState.wait,
      ),
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              AppCard(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: bg,
                        shape: BoxShape.circle,
                      ),
                      child: t.isTerminal
                          ? Icon(icon, size: 36, color: fg)
                          : Padding(
                              padding: const EdgeInsets.all(22),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: fg,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(title, style: context.text.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '${formatMoney(t.amount)} ',
                      style: context.text.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: t.trxNo));
                        if (context.mounted) {
                          showSnack(context, 'Đã sao chép mã giao dịch');
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          t.trxNo,
                          style: context.text.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            color: s.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '${trxTypeLabel(t.type)} · CIF ${t.cif} · ${t.channel}',
                      style: context.text.bodySmall?.copyWith(
                        color: s.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if ((failed || partial) && t.errorDescription != null) ...[
                const SizedBox(height: 12),
                NoteCard(
                  kind: CardKind.error,
                  icon: LucideIcons.triangleAlert,
                  text: Text(
                    '${t.errorDescription}'
                    '${partial ? ' Một phần giao dịch đã thực hiện, cần đối soát thủ công.' : ''}',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              AppCard(
                kind: CardKind.outlined,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  children: [
                    for (final (i, st) in steps.indexed)
                      _TimelineRow(
                        label: st.$1,
                        sub: st.$2,
                        state: st.$3,
                        last: i == steps.length - 1,
                      ),
                  ],
                ),
              ),
              if (t.retryOfTransactionId != null) ...[
                const SizedBox(height: 12),
                _LinkNote(
                  text: 'Lệnh này được tạo lại từ một giao dịch thất bại.',
                  action: 'Xem giao dịch gốc',
                  onTap: () =>
                      context.go('/transactions/${t.retryOfTransactionId}'),
                ),
              ],
              if (t.retriedByTransactionId != null) ...[
                const SizedBox(height: 12),
                _LinkNote(
                  text: 'Giao dịch này đã được tạo lại thành lệnh mới.',
                  action: 'Xem lệnh mới',
                  onTap: () =>
                      context.go('/transactions/${t.retriedByTransactionId}'),
                ),
              ],
              if (!t.isTerminal) ...[
                const SizedBox(height: 12),
                const NoteCard(
                  kind: CardKind.primaryContainer,
                  text: Text(
                    'Màn hình tự cập nhật mỗi 1,5 giây. Bạn có thể thoát và xem '
                    'lại ở tab Giao dịch.',
                  ),
                ),
              ],
            ],
          ),
        ),
        BottomBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canRetry)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _retry,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(
                      isSell ? 'Tạo lại lệnh bán' : 'Tạo lại lệnh mua',
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Về tổng quan'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkNote extends StatelessWidget {
  const _LinkNote({
    required this.text,
    required this.action,
    required this.onTap,
  });
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NoteCard(
    kind: CardKind.primaryContainer,
    text: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$text '),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(decoration: TextDecoration.underline),
          ),
        ),
      ],
    ),
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.sub,
    required this.state,
    required this.last,
  });
  final String label;
  final String? sub;
  final _StepState state;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tones = context.tones;
    final s = context.scheme;
    final (bg, fg, icon) = switch (state) {
      _StepState.done => (tones.okContainer, tones.onOk, LucideIcons.check),
      _StepState.fail => (tones.errorContainer, tones.onError, LucideIcons.x),
      _StepState.active => (
        tones.infoContainer,
        tones.onInfo,
        LucideIcons.loader,
      ),
      _StepState.wait => (
        s.surfaceContainerHighest,
        s.onSurfaceVariant,
        LucideIcons.circle,
      ),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, size: 14, color: fg),
              ),
              if (!last)
                Expanded(child: Container(width: 2, color: s.outlineVariant)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: context.text.titleMedium),
                  if (sub != null)
                    Text(
                      sub!,
                      style: context.text.bodySmall?.copyWith(
                        color: s.onSurfaceVariant,
                      ),
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
