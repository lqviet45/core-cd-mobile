import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../auth/pin_service.dart' show pinLength;
import 'theme.dart';

/// Hàng chấm tròn thể hiện số chữ số đã nhập (không bao giờ hiện chữ số).
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled, this.error = false});
  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    return Semantics(
      label: 'Đã nhập $filled trên $pinLength chữ số',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < pinLength; i++)
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < filled
                      ? (error ? s.error : s.primary)
                      : Colors.transparent,
                  border: Border.all(
                    color: error
                        ? s.error
                        : (i < filled ? s.primary : s.outline),
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ô nhập PIN 6 số: chấm tròn + bàn phím số lớn. Tự gọi [onCompleted] khi đủ số và xoá các chữ số sau khi xử lý xong.
class PinEntry extends StatefulWidget {
  const PinEntry({
    super.key,
    required this.onCompleted,
    this.error,
    this.onBiometric,
  });

  final Future<void> Function(String pin) onCompleted;

  /// Thông báo lỗi hiện dưới hàng chấm.
  final String? error;

  /// Có thì hiện phím vân tay ở góc trái dưới.
  final VoidCallback? onBiometric;

  @override
  State<PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<PinEntry> {
  String _pin = '';
  bool _busy = false;

  Future<void> _digit(String d) async {
    if (_busy || _pin.length >= pinLength) return;
    setState(() => _pin += d);
    if (_pin.length < pinLength) return;
    _busy = true;
    final entered = _pin;
    try {
      await widget.onCompleted(entered);
    } finally {
      if (mounted) {
        setState(() {
          _pin = '';
          _busy = false;
        });
      }
    }
  }

  void _delete() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _key(BuildContext context, String d) => _PinKey(
    label: d,
    onTap: () => _digit(d),
    child: Text(d, style: const TextStyle(fontSize: 26)),
  );

  @override
  Widget build(BuildContext context) {
    final s = context.scheme;
    final hasError = widget.error != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PinDots(filled: _pin.length, error: hasError),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: Center(
            child: Text(
              widget.error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: s.error),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 24,
            childAspectRatio: 1.25,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final d in const [
                '1',
                '2',
                '3',
                '4',
                '5',
                '6',
                '7',
                '8',
                '9',
              ])
                _key(context, d),
              if (widget.onBiometric != null)
                _PinKey(
                  label: 'Dùng vân tay hoặc khuôn mặt',
                  onTap: widget.onBiometric!,
                  plain: true,
                  child: Icon(
                    LucideIcons.fingerprint,
                    size: 28,
                    color: s.primary,
                  ),
                )
              else
                const SizedBox.shrink(),
              _key(context, '0'),
              _PinKey(
                label: 'Xoá một chữ số',
                onTap: _delete,
                plain: true,
                child: Icon(
                  LucideIcons.delete,
                  size: 26,
                  color: s.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.label,
    required this.onTap,
    required this.child,
    this.plain = false,
  });
  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool plain;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: ExcludeSemantics(
      child: Material(
        color: plain ? Colors.transparent : context.scheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    ),
  );
}
