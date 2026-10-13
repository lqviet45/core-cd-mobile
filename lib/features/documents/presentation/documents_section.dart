import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/money/money_gate.dart' show canWriteProvider;
import '../../../core/network/api_exception.dart';
import '../../../core/ui/snack.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../data/document_dto.dart';
import 'document_providers.dart';

/// Tài liệu của một đối tượng: xem/mở, chia sẻ, sinh PDF do hệ thống tạo và tải ảnh giấy tờ lên.
///
/// Chỉ hiện với Operator trở lên (API cũng chặn Viewer). Mọi thao tác dùng URL ngắn hạn do API cấp; app không
/// lưu tệp (tệp tạm khi chia sẻ bị xoá ngay).
class DocumentsSection extends ConsumerStatefulWidget {
  const DocumentsSection({
    super.key,
    required this.ownerType,
    required this.ownerId,
    this.generate,
    this.uploadKind,
    this.uploadLabel = 'Tải ảnh lên',
  });

  /// `Transaction | Certificate | Customer`.
  final String ownerType;
  final String ownerId;

  /// Đường dẫn API sinh tài liệu hệ thống (vd `/api/transactions/{id}/contract`) và nhãn nút; `null` nếu không có.
  final ({String path, String label})? generate;

  /// Loại tài liệu cho phép tải lên (vd `SignedContract`, `KycIdentity`); `null` nếu không cho tải.
  final String? uploadKind;
  final String uploadLabel;

  @override
  ConsumerState<DocumentsSection> createState() => _DocumentsSectionState();
}

class _DocumentsSectionState extends ConsumerState<DocumentsSection> {
  bool _busy = false;

  DocumentOwner get _owner => (type: widget.ownerType, id: widget.ownerId);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, _message(e), error: true);
    } on Object {
      // Plugin nền tảng (mở/chia sẻ/camera) lỗi: không lộ chi tiết kỹ thuật cho người dùng.
      if (mounted) {
        showSnack(
          context,
          'Không thực hiện được. Vui lòng thử lại.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(DocumentItem d) => _run(() async {
    final link = await ref.read(documentRepositoryProvider).downloadLink(d.id);
    final ok = await ref.read(documentOpenerProvider).open(link.url);
    if (!ok && mounted) {
      showSnack(context, 'Không có ứng dụng nào mở được tệp này.', error: true);
    }
  });

  Future<void> _share(DocumentItem d) => _run(() async {
    final repo = ref.read(documentRepositoryProvider);
    final link = await repo.downloadLink(d.id);
    final bytes = await repo.fetchBytes(link.url);
    await ref
        .read(documentOpenerProvider)
        .share(link.fileName, bytes, d.contentType);
  });

  Future<void> _generate() => _run(() async {
    await ref.read(documentRepositoryProvider).generate(widget.generate!.path);
    ref.invalidate(documentsProvider(_owner));
    if (mounted) showSnack(context, 'Đã tạo tài liệu.');
  });

  Future<void> _upload() async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
    if (camera == null) return;
    await _run(() async {
      final file = await ref
          .read(imageSourcePickerProvider)
          .pick(camera: camera);
      if (file == null) return; // người dùng huỷ
      await ref
          .read(documentRepositoryProvider)
          .upload(
            kind: widget.uploadKind!,
            ownerId: widget.ownerId,
            file: file,
          );
      ref.invalidate(documentsProvider(_owner));
      if (mounted) showSnack(context, 'Đã tải tài liệu lên.');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(canWriteProvider)) return const SizedBox.shrink();
    final docs = ref.watch(documentsProvider(_owner));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Tài liệu'),
        const SizedBox(height: 8),
        docs.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _Unavailable(
            error: e,
            onRetry: () => ref.invalidate(documentsProvider(_owner)),
          ),
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (items.isEmpty)
                const AppCard(
                  kind: CardKind.outlined,
                  child: Text('Chưa có tài liệu.'),
                )
              else
                ListGroup(
                  children: [
                    for (final d in items)
                      ListRow(
                        lead: const Lead(
                          square: true,
                          icon: LucideIcons.fileText,
                        ),
                        title: documentKindLabel(d.kind),
                        subtitle: d.isAvailable
                            ? '${d.fileName} · v${d.version} · ${formatDate(d.createdAt)}'
                            : 'Đang chờ xác nhận tệp',
                        trailing: d.isAvailable
                            ? IconButton(
                                tooltip: 'Chia sẻ',
                                onPressed: _busy ? null : () => _share(d),
                                icon: const Icon(LucideIcons.share2, size: 20),
                              )
                            : null,
                        onTap: d.isAvailable && !_busy ? () => _open(d) : null,
                      ),
                  ],
                ),
              if (widget.generate != null || widget.uploadKind != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (widget.generate != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: _busy ? null : _generate,
                        icon: const Icon(LucideIcons.filePlus, size: 18),
                        label: Text(widget.generate!.label),
                      ),
                    if (widget.uploadKind != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: _busy ? null : _upload,
                        icon: const Icon(LucideIcons.camera, size: 18),
                        label: Text(widget.uploadLabel),
                      ),
                  ],
                ),
              ],
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _message(ApiException e) =>
    e.status == 503 ? 'Kho tài liệu chưa được bật trên máy chủ.' : e.message;

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final e = error is ApiException ? error as ApiException : null;
    return AppCard(
      kind: CardKind.outlined,
      child: Row(
        children: [
          Expanded(
            child: Text(
              e == null ? 'Không tải được tài liệu.' : _message(e),
              style: TextStyle(color: context.scheme.onSurfaceVariant),
            ),
          ),
          if (e?.status != 503)
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
