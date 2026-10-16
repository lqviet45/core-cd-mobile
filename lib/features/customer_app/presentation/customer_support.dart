import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/providers.dart';
import 'kh_theme.dart';
import 'kh_widgets.dart';

/// Số hotline cấu hình qua `SUPPORT_PHONE`; rỗng nếu chưa cấu hình (khi đó UI chỉ hiện hướng dẫn chung).
final custSupportPhoneProvider = Provider<String>(
  (ref) => ref.watch(appConfigProvider).supportPhone.trim(),
);

/// Hàm mở trình quay số – tách ra để test thay thế được.
final custUrlLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// `tel:` chỉ giữ chữ số và dấu `+` ở đầu: bỏ khoảng trắng/dấu chấm để trình quay số hiểu đúng.
Uri telUri(String phone) {
  final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
  return Uri(scheme: 'tel', path: cleaned);
}

Future<void> callSupport(BuildContext context, WidgetRef ref) async {
  final phone = ref.read(custSupportPhoneProvider);
  if (phone.isEmpty) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  var ok = false;
  try {
    ok = await ref.read(custUrlLauncherProvider)(telUri(phone));
  } on Object {
    ok = false;
  }
  if (!ok) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Không mở được trình quay số. Hãy gọi $phone.')),
    );
  }
}

/// Nút "Gọi hotline" – tự ẩn khi chưa cấu hình số.
class KhCallSupportButton extends ConsumerWidget {
  const KhCallSupportButton({
    super.key,
    this.kind = KhButtonKind.outlined,
    this.height = 48,
  });
  final KhButtonKind kind;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(custSupportPhoneProvider);
    if (phone.isEmpty) return const SizedBox.shrink();
    return KhButton(
      label: 'Gọi hotline $phone',
      icon: LucideIcons.phone,
      kind: kind,
      height: height,
      onPressed: () => callSupport(context, ref),
    );
  }
}

/// Dòng "Hotline hỗ trợ" trong màn Tài khoản – tự ẩn khi chưa cấu hình số.
class KhSupportRow extends ConsumerWidget {
  const KhSupportRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(custSupportPhoneProvider);
    if (phone.isEmpty) return const SizedBox.shrink();
    final k = context.kh;
    return KhRow(
      minHeight: 56,
      leading: const KhIconTile(LucideIcons.headset),
      title: 'Hotline hỗ trợ',
      subtitle: phone,
      trailing: Icon(LucideIcons.phone, size: 20, color: k.ink3),
      onTap: () => callSupport(context, ref),
    );
  }
}
