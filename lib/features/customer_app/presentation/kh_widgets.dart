import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/network/api_exception.dart';
import 'kh_theme.dart';

/// Thành phần giao diện của app khách hàng, bám các lớp `k-*` trong `kh.css`.

// ── bố cục ──────────────────────────────────────────────────────────
/// Thanh trên (`k-top`): nút quay lại tròn 44dp, tiêu đề, hành động.
class KhTopBar extends StatelessWidget {
  const KhTopBar({
    super.key,
    this.title,
    this.onBack,
    this.trailing,
    this.height = 64,
  });
  final String? title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              if (onBack != null)
                KhIconButton(
                  icon: LucideIcons.chevronLeft,
                  label: 'Quay lại',
                  onPressed: onBack,
                )
              else
                const SizedBox(width: 0),
              Expanded(
                child: title == null
                    ? const SizedBox()
                    : Semantics(
                        header: true,
                        child: Text(
                          title!,
                          textAlign: TextAlign.center,
                          style: KhType.t2.copyWith(color: k.ink),
                        ),
                      ),
              ),
              if (trailing != null)
                trailing!
              else if (onBack != null)
                const SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }
}

class KhIconButton extends StatelessWidget {
  const KhIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.flat = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: flat ? Colors.transparent : k.sf,
          shape: CircleBorder(
            side: BorderSide(color: flat ? Colors.transparent : k.line),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 20, color: k.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề lớn của màn tab (`k-large`).
class KhLargeTitle extends StatelessWidget {
  const KhLargeTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: KhType.d2.copyWith(color: k.ink)),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!, style: KhType.s.copyWith(color: k.ink2)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tiêu đề nhóm (`k-sec`): tên + liên kết bên phải.
class KhSection extends StatelessWidget {
  const KhSection(this.title, {super.key, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: KhType.t2.copyWith(color: k.ink)),
            ),
          ),
          if (actionLabel != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: k.pri,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class KhGroupLabel extends StatelessWidget {
  const KhGroupLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 18 / 13,
          fontWeight: FontWeight.w600,
          color: context.kh.ink3,
          letterSpacing: 0.26,
        ),
      ),
    ),
  );
}

// ── thẻ & danh sách ─────────────────────────────────────────────────
class KhCard extends StatelessWidget {
  const KhCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
    this.transparent = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    return Material(
      color: transparent ? Colors.transparent : k.sf,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor ?? k.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Nhóm hàng (`k-list`): nền trắng, viền, bo 20, vạch giữa các hàng.
class KhList extends StatelessWidget {
  const KhList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    return Material(
      color: k.sf,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: k.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: k.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

class KhRow extends StatelessWidget {
  const KhRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.minHeight = 60,
    this.wrapSubtitle = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.titleWeight = FontWeight.w500,
  });
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double minHeight;
  final bool wrapSubtitle;
  final EdgeInsetsGeometry padding;
  final FontWeight titleWeight;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: wrapSubtitle ? 3 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: KhType.b.copyWith(
                        color: k.ink,
                        fontWeight: titleWeight,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: wrapSubtitle ? 3 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: KhType.s.copyWith(color: k.ink3),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 14), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Hàng "nhãn — giá trị" trong danh sách thông tin (chi tiết CCTG, tài khoản).
class KhInfoRow extends StatelessWidget {
  const KhInfoRow(
    this.label,
    this.value, {
    super.key,
    this.minHeight = 56,
    this.mono = false,
  });
  final String label;
  final String value;
  final double minHeight;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: KhType.s.copyWith(color: k.ink2)),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: KhType.b.copyWith(
                  color: k.ink,
                  fontWeight: FontWeight.w600,
                  fontFeatures: KhType.nums,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum KhTone { primary, amber, muted, ok }

/// Ô biểu tượng 40dp bo 12 (`k-ic`).
class KhIconTile extends StatelessWidget {
  const KhIconTile(
    this.icon, {
    super.key,
    this.tone = KhTone.primary,
    this.size = 40,
  });
  final IconData icon;
  final KhTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    final (bg, fg) = switch (tone) {
      KhTone.primary => (k.priT, k.priInk),
      KhTone.amber => (k.ambT, k.amb),
      KhTone.muted => (k.sf2, k.ink2),
      KhTone.ok => (k.okT, k.ok),
    };
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(size > 40 ? 14 : 12),
        ),
        child: Icon(icon, size: 20, color: fg),
      ),
    );
  }
}

/// Ô ngày 44×48 (`k-date`): ngày to, tháng nhỏ viết hoa; hổ phách khi sắp tới hạn.
class KhDateBadge extends StatelessWidget {
  const KhDateBadge(this.date, {super.key, this.soon = false});
  final DateTime date;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    final d = date.toUtc();
    return ExcludeSemantics(
      child: Container(
        width: 44,
        height: 48,
        decoration: BoxDecoration(
          color: soon ? k.ambT : k.sf2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              d.day.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 17,
                height: 1.05,
                fontWeight: FontWeight.w600,
                color: soon ? k.amb : k.ink,
              ),
            ),
            Text(
              'TH${d.month}',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.05,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: soon ? k.amb : k.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum KhPillKind { primary, soon, done, ok, bad }

/// Nhãn trạng thái (`k-pill`): luôn có chữ, chấm tròn đầu nhãn.
class KhPill extends StatelessWidget {
  const KhPill(this.label, {super.key, this.kind = KhPillKind.primary});
  final String label;
  final KhPillKind kind;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    final (bg, fg) = switch (kind) {
      KhPillKind.primary => (k.priT, k.priInk),
      KhPillKind.soon => (k.ambT, k.amb),
      KhPillKind.done => (k.sf2, k.ink2),
      KhPillKind.ok => (k.okT, k.ok),
      KhPillKind.bad => (k.badT, k.bad),
    };
    return Semantics(
      label: 'Trạng thái: $label',
      child: ExcludeSemantics(
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class KhBar extends StatelessWidget {
  const KhBar(this.value, {super.key, this.soon = false});
  final double value;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    return Semantics(
      label: 'Tiến độ kỳ hạn ${(value * 100).round()}%',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: k.sf2,
            color: soon ? k.ambBar : k.pri,
          ),
        ),
      ),
    );
  }
}

class KhMeta extends StatelessWidget {
  const KhMeta({
    super.key,
    required this.left,
    required this.center,
    required this.right,
    this.soon = false,
  });
  final String left;
  final String center;
  final String right;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    Widget cell(String t, TextStyle style, TextAlign align) => Expanded(
      child: Text(
        t,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          cell(left, KhType.c.copyWith(color: k.ink3), TextAlign.left),
          cell(
            center,
            KhType.c.copyWith(
              color: soon ? k.amb : k.ink2,
              fontWeight: FontWeight.w600,
            ),
            TextAlign.center,
          ),
          cell(right, KhType.c.copyWith(color: k.ink3), TextAlign.right),
        ],
      ),
    );
  }
}

/// Thẻ chính màu teal (`k-hero`) với hai vòng tròn mờ trang trí.
class KhHero extends StatelessWidget {
  const KhHero({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 22, 22, 18),
    this.radius = 24,
    this.borderRadius,
    this.shadow = true,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Ghi đè bo góc (vd. màn đăng nhập chỉ bo hai góc dưới).
  final BorderRadius? borderRadius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    return Container(
      decoration: BoxDecoration(
        color: k.hero,
        borderRadius: borderRadius ?? BorderRadius.circular(radius),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: k.heroShadow,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -74,
            top: -96,
            child: ExcludeSemantics(
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x0DFFFFFF), width: 38),
                ),
              ),
            ),
          ),
          Positioned(
            right: 26,
            top: 34,
            child: ExcludeSemantics(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x0DFFFFFF), width: 12),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

// ── nút, ô nhập, chip ───────────────────────────────────────────────
enum KhButtonKind { filled, outlined, tonal }

class KhButton extends StatelessWidget {
  const KhButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = KhButtonKind.filled,
    this.busy = false,
    this.height = 52,
    this.expand = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final KhButtonKind kind;
  final bool busy;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    final (bg, fg, side) = switch (kind) {
      KhButtonKind.filled => (k.pri, k.onPri, BorderSide.none),
      KhButtonKind.outlined => (
        Colors.transparent,
        k.priInk,
        BorderSide(color: k.line2),
      ),
      KhButtonKind.tonal => (k.priT, k.priInk, BorderSide.none),
    };
    final enabled = onPressed != null && !busy;
    final button = Material(
      color: enabled ? bg : bg.withValues(alpha: 0.5),
      shape: StadiumBorder(side: side),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                else ...[
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: height >= 52 ? 16 : 15,
                        height: 24 / 16,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: button,
    );
  }
}

/// Ô nhập (`k-field`): nhãn phía trên, khung 56dp bo 14; viền 2dp màu chính khi đang nhập.
class KhField extends StatefulWidget {
  const KhField({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.errorText,
    this.hint,
    this.inputFormatters,
    this.autofocus = false,
  });
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final String? errorText;
  final String? hint;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;

  @override
  State<KhField> createState() => _KhFieldState();
}

class _KhFieldState extends State<KhField> {
  final _focus = FocusNode();
  bool _hide = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    final focused = _focus.hasFocus;
    final hasError = widget.errorText != null;
    final borderColor = hasError ? k.bad : (focused ? k.pri : k.line2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 0, 6),
          child: Text(
            widget.label,
            style: KhType.s.copyWith(
              color: k.ink2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          height: 56,
          padding: EdgeInsets.symmetric(
            horizontal: focused || hasError ? 15 : 16,
          ),
          decoration: BoxDecoration(
            color: k.sf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: focused || hasError ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 20, color: k.ink3),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  obscureText: widget.obscure && _hide,
                  keyboardType: widget.keyboardType,
                  autofillHints: widget.autofillHints,
                  textInputAction: widget.textInputAction,
                  onSubmitted: widget.onSubmitted,
                  inputFormatters: widget.inputFormatters,
                  autocorrect: false,
                  enableSuggestions: false,
                  cursorColor: k.pri,
                  style: TextStyle(fontSize: 16, color: k.ink),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: TextStyle(fontSize: 16, color: k.ink3),
                  ),
                ),
              ),
              if (widget.obscure)
                Semantics(
                  button: true,
                  label: _hide ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  child: InkResponse(
                    onTap: () => setState(() => _hide = !_hide),
                    radius: 24,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        _hide ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 20,
                        color: k.ink3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 0, 0),
            child: Text(
              widget.errorText!,
              style: KhType.c.copyWith(color: k.bad),
            ),
          ),
      ],
    );
  }
}

/// Dãy chip lọc (`k-chips`): chip đang chọn nền `pri-t`, có dấu tick.
class KhChips<T> extends StatelessWidget {
  const KhChips({
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
    final k = context.kh;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (v, label) = options[i];
          final on = v == value;
          return Semantics(
            button: true,
            selected: on,
            label: label,
            excludeSemantics: true,
            child: Material(
              color: on ? k.priT : Colors.transparent,
              shape: StadiumBorder(
                side: BorderSide(color: on ? Colors.transparent : k.line2),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onChanged(v),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (on) ...[
                        Icon(LucideIcons.check, size: 16, color: k.priInk),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                          color: on ? k.priInk : k.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class KhAvatar extends StatelessWidget {
  const KhAvatar(this.initials, {super.key});
  final String initials;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    return ExcludeSemantics(
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: k.priT, shape: BoxShape.circle),
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: k.priInk,
          ),
        ),
      ),
    );
  }
}

/// Ghi chú nền màu (`k-note`).
class KhNote extends StatelessWidget {
  const KhNote(
    this.text, {
    super.key,
    this.icon = LucideIcons.info,
    this.amber = false,
  });
  final String text;
  final IconData icon;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    final bg = amber ? k.ambT : k.priT;
    final fg = amber ? k.amb : k.priInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: KhType.s.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }
}

// ── điều hướng dưới ─────────────────────────────────────────────────
class KhNavItem {
  const KhNavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

class KhNavBar extends StatelessWidget {
  const KhNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onSelected,
  });
  final List<KhNavItem> items;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    return Material(
      color: k.sf,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: k.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 76,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        label: items[i].label,
                        excludeSemantics: true,
                        child: InkResponse(
                          onTap: () => onSelected(i),
                          highlightShape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 60,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: i == index
                                      ? k.priT
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  items[i].icon,
                                  size: 22,
                                  color: i == index ? k.priInk : k.ink3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                items[i].label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 16 / 12,
                                  fontWeight: i == index
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: i == index ? k.ink : k.ink3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── trạng thái tải / rỗng / lỗi ─────────────────────────────────────
class KhEmpty extends StatelessWidget {
  const KhEmpty({
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
    final k = context.kh;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: k.sf2, shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: k.ink2),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: KhType.t2.copyWith(color: k.ink),
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: KhType.s.copyWith(color: k.ink2),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Lỗi tải: thông điệp thân thiện + mã vết (để báo hỗ trợ) + nút thử lại. 403 → khung "không có quyền".
class KhError extends StatelessWidget {
  const KhError({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    final api = error is ApiException ? error as ApiException : null;
    final offline = api?.isNetwork ?? false;
    return KhEmpty(
      icon: offline ? LucideIcons.wifiOff : LucideIcons.triangleAlert,
      title: offline ? 'Không kết nối được' : 'Không tải được dữ liệu',
      message: api?.message ?? 'Đã có lỗi xảy ra. Vui lòng thử lại.',
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (api?.traceId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SelectableText(
                'Mã vết: ${api!.traceId}',
                style: KhType.c.copyWith(color: k.ink3),
              ),
            ),
          if (onRetry != null)
            KhButton(
              label: 'Thử lại',
              kind: KhButtonKind.outlined,
              height: 44,
              expand: false,
              onPressed: onRetry,
            ),
        ],
      ),
    );
  }
}

/// Khung chờ dạng danh sách thẻ.
class KhSkeleton extends StatelessWidget {
  const KhSkeleton({super.key, this.rows = 3});
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          for (var i = 0; i < rows; i++) ...[
            const KhCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CDS000000000000000'),
                  SizedBox(height: 8),
                  Text('CCTG 12 tháng đang tải'),
                  SizedBox(height: 8),
                  Text('7,30%/năm · lãi hàng tháng'),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
