import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../network/api_exception.dart';
import '../utils/format.dart';
import '../utils/labels.dart';
import 'theme.dart';

/// Biến thể thẻ trong thiết kế (`.m-card`).
enum CardKind { filled, outlined, primary, primaryContainer, warn, error }

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.kind = CardKind.filled,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final CardKind kind;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Màu chữ mặc định trên thẻ (để các widget con tự đọc đúng tương phản).
  static Color onColor(BuildContext context, CardKind kind) {
    final s = context.scheme;
    final t = context.tones;
    return switch (kind) {
      CardKind.primary => s.onPrimary,
      CardKind.primaryContainer => s.onPrimaryContainer,
      CardKind.warn => t.onWarn,
      CardKind.error => t.onError,
      _ => s.onSurface,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    final t = context.tones;
    final bg = switch (kind) {
      CardKind.filled => s.surfaceContainerLow,
      CardKind.outlined => Colors.transparent,
      CardKind.primary => s.primary,
      CardKind.primaryContainer => s.primaryContainer,
      CardKind.warn => t.warnContainer,
      CardKind.error => t.errorContainer,
    };
    final fg = onColor(context, kind);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        side: kind == CardKind.outlined
            ? BorderSide(color: s.outlineVariant)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: fg),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Nhãn trạng thái (`.m-st`): bo 8, cao 24, chữ 12/500.
class StatusChip extends StatelessWidget {
  const StatusChip(this.item, {super.key});
  final Labeled item;

  @override
  Widget build(BuildContext context) {
    final t = context.tones;
    return Semantics(
      label: 'Trạng thái: ${item.label}',
      child: ExcludeSemantics(
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.bg(item.tone),
            borderRadius: BorderRadius.circular(Tokens.radiusChip),
          ),
          child: Text(
            item.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: t.fg(item.tone),
            ),
          ),
        ),
      ),
    );
  }
}

/// Số tiền với chữ số đều nhau (tabular) để các dòng thẳng cột.
class MoneyText extends StatelessWidget {
  const MoneyText(this.value, {super.key, this.style, this.compact = false});
  final Decimal? value;
  final TextStyle? style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text(
      compact ? '${formatCompact(value)} ₫' : formatMoney(value),
      style: base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Thanh tiến độ 6dp (`.m-pr`).
class AppProgress extends StatelessWidget {
  const AppProgress(
    this.value, {
    super.key,
    this.warn = false,
    this.semanticLabel,
    this.fill,
    this.track,
  });

  /// 0–1.
  final double value;
  final bool warn;
  final String? semanticLabel;

  /// Ghi đè màu thanh/nền khi đặt trên thẻ có màu (ví dụ thẻ `primary`).
  final Color? fill;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    return Semantics(
      label: semanticLabel,
      value: '${(value.clamp(0, 1) * 100).round()}%',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value.clamp(0, 1),
            minHeight: 6,
            backgroundColor: track ?? s.surfaceContainerHighest,
            color: fill ?? (warn ? Tokens.warnBar : s.primary),
          ),
        ),
      ),
    );
  }
}

/// Chip lọc đơn chọn (`.m-chip`).
class FilterChipsRow<T> extends StatelessWidget {
  const FilterChipsRow({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.gap,
          vertical: 8,
        ),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (v, label) = options[i];
          final on = v == value;
          return Semantics(
            button: true,
            selected: on,
            label: label,
            child: InkWell(
              borderRadius: BorderRadius.circular(Tokens.radiusChip),
              onTap: () => onChanged(v),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: on ? s.secondaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(Tokens.radiusChip),
                  border: on ? null : Border.all(color: s.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (on) ...[
                      Icon(
                        LucideIcons.check,
                        size: 16,
                        color: s.onSecondaryContainer,
                      ),
                      const SizedBox(width: 6),
                    ],
                    ExcludeSemantics(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: on
                              ? s.onSecondaryContainer
                              : s.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Ô tìm kiếm dạng viên thuốc.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.gap),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: s.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(LucideIcons.search, size: 20, color: s.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: s.onSurfaceVariant),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isCollapsed: true,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

/// Tiêu đề lớn ở đầu màn hình tab (`.m-ab.lg`).
class BigHeader extends StatelessWidget {
  const BigHeader(this.title, {super.key, this.actions = const []});
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 56,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ),
            Semantics(
              header: true,
              child: Text(title, style: context.text.headlineMedium),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút icon 48dp có nhãn truy cập.
class IconBtn extends StatelessWidget {
  const IconBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.badge,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    return Semantics(
      button: true,
      label: badge != null && badge! > 0 ? '$label, $badge mới' : label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: onPressed,
                icon: Icon(icon, color: s.onSurfaceVariant),
                tooltip: label,
              ),
              if (badge != null && badge! > 0)
                Positioned(
                  top: 9,
                  right: 9,
                  child: IgnorePointer(
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge! > 99 ? '99+' : '$badge',
                        style: TextStyle(
                          color: s.onError,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề nhóm (`.m-sec`) kèm liên kết "Xem tất cả".
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: s.onSurfaceVariant,
                ),
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(color: s.primary, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }
}

/// Nhóm hàng danh sách (`.m-list`): nền surfaceContainerLow, bo 16, đường kẻ giữa các hàng.
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    return Material(
      color: s.surfaceContainerLow,
      borderRadius: BorderRadius.circular(Tokens.radiusCard),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: s.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}

enum LeadKind { primary, warn, error, ok }

/// Biểu tượng/ảnh đại diện đầu hàng (`.lead`): tròn hoặc vuông bo 12.
class Lead extends StatelessWidget {
  const Lead({
    super.key,
    this.text,
    this.icon,
    this.square = false,
    this.kind = LeadKind.primary,
    this.child,
  });
  final String? text;
  final IconData? icon;
  final bool square;
  final LeadKind kind;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    final t = context.tones;
    final (bg, fg) = switch (kind) {
      LeadKind.primary => (s.primaryContainer, s.onPrimaryContainer),
      LeadKind.warn => (t.warnContainer, t.onWarn),
      LeadKind.error => (t.errorContainer, t.onError),
      LeadKind.ok => (t.okContainer, t.onOk),
    };
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(12) : null,
        ),
        child:
            child ??
            (icon != null
                ? Icon(icon, size: 20, color: fg)
                : Text(
                    text ?? '',
                    style: TextStyle(color: fg, fontWeight: FontWeight.w500),
                  )),
      ),
    );
  }
}

/// Hàng danh sách (`.m-li`): lead — tiêu đề/phụ đề — phần phải.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    this.lead,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.chevron = false,
  });
  final Widget? lead;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (lead != null) ...[lead!, const SizedBox(width: 16)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: context.text.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: context.text.bodyMedium?.copyWith(
                          color: s.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              if (chevron) ...[
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.chevronRight,
                  size: 20,
                  color: s.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Hàng "nhãn — giá trị" trong danh sách thông tin (nhãn mờ bên trái, giá trị đậm bên phải).
class InfoRow extends StatelessWidget {
  const InfoRow(
    this.label,
    this.value, {
    super.key,
    this.valueWidget,
    this.mono = false,
  });
  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: s.onSurfaceVariant)),
            const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child:
                    valueWidget ??
                    Text(
                      value ?? '—',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFamily: mono ? 'monospace' : null,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trạng thái rỗng (`.m-empty`).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = LucideIcons.inbox,
    this.action,
  });
  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: s.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: s.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                style: context.text.bodyMedium?.copyWith(
                  color: s.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Lỗi tải dữ liệu: thông điệp thân thiện + mã vết + nút thử lại; 403 hiện khung "không có quyền".
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    if (api?.isForbidden ?? false) {
      return const EmptyState(
        icon: LucideIcons.lock,
        title: 'Bạn không có quyền xem mục này',
        message: 'Liên hệ quản trị viên nếu cần được cấp quyền.',
      );
    }
    final offline = api?.isNetwork ?? false;
    return EmptyState(
      icon: offline ? LucideIcons.wifiOff : LucideIcons.triangleAlert,
      title: offline ? 'Không kết nối được' : 'Không tải được dữ liệu',
      message: api?.message ?? 'Đã có lỗi xảy ra.',
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (api?.traceId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SelectableText(
                'Mã vết: ${api!.traceId}',
                style: context.text.bodySmall,
              ),
            ),
          if (onRetry != null)
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

/// Dải thông báo mất mạng (`.m-card.er` trong MobStates).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.savedAt});

  /// Thời điểm của dữ liệu đang hiển thị từ bản đệm (nếu có).
  final DateTime? savedAt;

  @override
  Widget build(BuildContext context) {
    final t = context.tones;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.errorContainer,
          borderRadius: BorderRadius.circular(Tokens.radiusCard),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.wifiOff, size: 20, color: t.onError),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Không có mạng. ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: savedAt == null
                          ? 'Đang hiển thị dữ liệu đã tải; các thao tác ghi bị khoá.'
                          : 'Đang hiển thị dữ liệu lưu lúc ${formatDateTime(savedAt)}. Nút ghi bị khoá.',
                    ),
                  ],
                ),
                style: TextStyle(color: t.onError, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung chờ khi đang tải danh sách.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 6});
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Tokens.gap),
        itemCount: rows,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const AppCard(
          kind: CardKind.outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CDS000000000000000'),
              SizedBox(height: 8),
              Text('Tên khách hàng đang tải'),
              SizedBox(height: 8),
              Text('12 tháng · 0,00%/năm'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thanh hành động cố định ở đáy màn hình (`.m-bar`).
class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: context.scheme.surfaceContainer,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: child,
      ),
    ),
  );
}

/// Thẻ cảnh báo/ghi chú trong màn hình ghi (`.m-card.w` / `.m-card.pc`).
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.text,
    this.icon = LucideIcons.info,
    this.kind = CardKind.warn,
  });
  final Widget text;
  final IconData icon;
  final CardKind kind;

  @override
  Widget build(BuildContext context) {
    final fg = AppCard.onColor(context, kind);
    return AppCard(
      kind: kind,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle.merge(
              style: context.text.bodyMedium?.copyWith(color: fg),
              child: text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dòng "nhãn … giá trị" trong bảng tóm tắt số liệu (`.m-card` nền sc-hi).
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.rows, this.total});
  final List<(String, String)> rows;
  final (String, String)? total;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (final (l, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l,
                      style: context.text.bodyMedium?.copyWith(
                        color: s.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(v, style: context.text.bodyMedium),
                ],
              ),
            ),
          if (total != null) ...[
            Divider(color: s.outlineVariant),
            Row(
              children: [
                Expanded(
                  child: Text(total!.$1, style: context.text.titleMedium),
                ),
                Text(total!.$2, style: context.text.titleLarge),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
