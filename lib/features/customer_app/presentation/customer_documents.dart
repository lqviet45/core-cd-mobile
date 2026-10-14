import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/format.dart';
import '../data/customer_app_dto.dart';
import 'customer_labels.dart';
import 'customer_providers.dart';
import 'kh_theme.dart';
import 'kh_widgets.dart';

class PlatformCustDocumentOpener implements CustDocumentOpener {
  const PlatformCustDocumentOpener();

  @override
  Future<bool> open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

final custDocumentOpenerProvider = Provider<CustDocumentOpener>(
  (ref) => const PlatformCustDocumentOpener(),
);

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Xin URL ngắn hạn (5 phút, có ghi nhật ký ở máy chủ) rồi mở bằng ứng dụng hệ thống. Không log/lưu URL.
Future<void> openCustDocument(
  BuildContext context,
  WidgetRef ref,
  CustDocument d,
) async {
  try {
    final link = await ref.read(custRepositoryProvider).downloadLink(d.id);
    final ok = await ref.read(custDocumentOpenerProvider).open(link.url);
    if (!ok && context.mounted) {
      _toast(context, 'Không mở được tài liệu trên thiết bị này.');
    }
  } on ApiException catch (e) {
    if (context.mounted) _toast(context, e.message);
  } on Object {
    if (context.mounted) {
      _toast(context, 'Không mở được tài liệu. Vui lòng thử lại.');
    }
  }
}

/// Nút "Hợp đồng" ở chi tiết CCTG: một tài liệu thì mở luôn, nhiều thì chọn, không có thì báo.
Future<void> openCertificateDocuments(
  BuildContext context,
  WidgetRef ref,
  String certificateId,
) async {
  final key = (type: 'certificates', id: certificateId);
  List<CustDocument> docs;
  try {
    docs = await ref.refresh(custDocumentsProvider(key).future);
  } on ApiException catch (e) {
    if (context.mounted) _toast(context, e.message);
    return;
  } on Object {
    if (context.mounted) _toast(context, 'Không tải được danh sách tài liệu.');
    return;
  }
  if (!context.mounted) return;
  if (docs.isEmpty) {
    _toast(
      context,
      'Chưa có hợp đồng. Tài liệu sẽ xuất hiện khi ngân hàng phát hành.',
    );
    return;
  }
  if (docs.length == 1) {
    await openCustDocument(context, ref, docs.single);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tài liệu', style: KhType.t1.copyWith(color: ctx.kh.ink)),
            const SizedBox(height: 12),
            _DocList(
              docs: docs,
              onOpen: (d) => openCustDocument(context, ref, d),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DocList extends StatelessWidget {
  const _DocList({required this.docs, required this.onOpen});
  final List<CustDocument> docs;
  final void Function(CustDocument) onOpen;

  @override
  Widget build(BuildContext context) => KhList(
    children: [
      for (final d in docs)
        KhRow(
          leading: const KhIconTile(LucideIcons.fileText),
          title: custDocumentKindLabel(d.kind),
          subtitle: '${formatDate(d.createdAt)} · ${fileSizeLabel(d.size)}',
          trailing: Icon(
            LucideIcons.externalLink,
            size: 20,
            color: context.kh.ink3,
          ),
          onTap: () => onOpen(d),
        ),
    ],
  );
}

/// Danh sách tài liệu của một giao dịch (màn chi tiết giao dịch).
class CustDocumentsSection extends ConsumerWidget {
  const CustDocumentsSection({
    super.key,
    required this.ownerType,
    required this.ownerId,
  });

  /// `certificates | transactions`.
  final String ownerType;
  final String ownerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (type: ownerType, id: ownerId);
    final docs = ref.watch(custDocumentsProvider(key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const KhSection('Tài liệu'),
        const SizedBox(height: 12),
        docs.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => KhError(
            error: e,
            onRetry: () => ref.invalidate(custDocumentsProvider(key)),
          ),
          data: (list) => list.isEmpty
              ? const KhNote(
                  'Chưa có tài liệu. Tài liệu sẽ xuất hiện khi ngân hàng phát hành.',
                  icon: LucideIcons.fileText,
                )
              : _DocList(
                  docs: list,
                  onOpen: (d) => openCustDocument(context, ref, d),
                ),
        ),
      ],
    );
  }
}
