import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/ui/snack.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../data/customer_app_dto.dart';
import 'customer_labels.dart';
import 'customer_providers.dart';

class PlatformCustDocumentOpener implements CustDocumentOpener {
  const PlatformCustDocumentOpener();

  @override
  Future<bool> open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

final custDocumentOpenerProvider = Provider<CustDocumentOpener>(
  (ref) => const PlatformCustDocumentOpener(),
);

/// Hợp đồng/chứng chỉ của một CCTG hoặc giao dịch. Mỗi lần mở cấp một URL ngắn hạn (5 phút) và được ghi nhật ký
/// ở máy chủ; app không lưu tệp và không ghi URL vào log.
class CustDocumentsSection extends ConsumerStatefulWidget {
  const CustDocumentsSection({
    super.key,
    required this.ownerType,
    required this.ownerId,
  });

  /// `certificates | transactions`.
  final String ownerType;
  final String ownerId;

  @override
  ConsumerState<CustDocumentsSection> createState() => _State();
}

class _State extends ConsumerState<CustDocumentsSection> {
  String? _opening;

  Future<void> _open(CustDocument d) async {
    if (_opening != null) return;
    setState(() => _opening = d.id);
    try {
      final link = await ref.read(custRepositoryProvider).downloadLink(d.id);
      final ok = await ref.read(custDocumentOpenerProvider).open(link.url);
      if (!ok && mounted) {
        showSnack(
          context,
          'Không mở được tài liệu trên thiết bị này.',
          error: true,
        );
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } on Object {
      if (mounted) {
        showSnack(
          context,
          'Không mở được tài liệu. Vui lòng thử lại.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (type: widget.ownerType, id: widget.ownerId);
    final docs = ref.watch(custDocumentsProvider(key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Tài liệu'),
        const SizedBox(height: 8),
        docs.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(custDocumentsProvider(key)),
          ),
          data: (list) => list.isEmpty
              ? const NoteCard(
                  icon: LucideIcons.fileText,
                  kind: CardKind.outlined,
                  text: Text(
                    'Chưa có tài liệu. Tài liệu sẽ xuất hiện khi ngân hàng phát hành.',
                  ),
                )
              : ListGroup(
                  children: [
                    for (final d in list)
                      ListRow(
                        lead: const Lead(
                          icon: LucideIcons.fileText,
                          square: true,
                        ),
                        title: custDocumentKindLabel(d.kind),
                        subtitle:
                            '${formatDate(d.createdAt)} · ${fileSizeLabel(d.size)}',
                        trailing: _opening == d.id
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(LucideIcons.externalLink, size: 20),
                        onTap: () => _open(d),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
