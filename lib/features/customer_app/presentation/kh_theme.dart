import 'package:flutter/material.dart';

import '../../../core/ui/theme.dart' show ToneColors;

/// Bảng màu của app khách hàng, lấy nguyên từ `kh.css` của thiết kế (nền trung tính ấm + MỘT màu teal + MỘT màu hổ phách
/// chỉ cho "sắp đáo hạn"; trạng thái luôn đi kèm chữ).
@immutable
class KhColors extends ThemeExtension<KhColors> {
  const KhColors({
    required this.bg,
    required this.sf,
    required this.sf2,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.line2,
    required this.hero,
    required this.pri,
    required this.onPri,
    required this.priT,
    required this.priInk,
    required this.amb,
    required this.ambT,
    required this.ambBar,
    required this.ok,
    required this.okT,
    required this.bad,
    required this.badT,
    required this.heroShadow,
  });

  static const light = KhColors(
    bg: Color(0xFFF4F3EE),
    sf: Color(0xFFFFFFFF),
    sf2: Color(0xFFECEBE4),
    ink: Color(0xFF10201D),
    ink2: Color(0xFF43524E),
    ink3: Color(0xFF5C6A66),
    line: Color(0xFFE3E1D9),
    line2: Color(0xFFCFCDC3),
    hero: Color(0xFF0B5D55),
    pri: Color(0xFF0B5D55),
    onPri: Color(0xFFFFFFFF),
    priT: Color(0xFFDFEDE9),
    priInk: Color(0xFF073F39),
    amb: Color(0xFF8A5A00),
    ambT: Color(0xFFFBEFD6),
    ambBar: Color(0xFFC98A12),
    ok: Color(0xFF1D6B45),
    okT: Color(0xFFE1F0E7),
    bad: Color(0xFFA8281F),
    badT: Color(0xFFFBE6E3),
    heroShadow: Color(0x0F10201D),
  );

  static const dark = KhColors(
    bg: Color(0xFF0C1312),
    sf: Color(0xFF141D1B),
    sf2: Color(0xFF1C2826),
    ink: Color(0xFFE7EDEB),
    ink2: Color(0xFFB8C5C1),
    ink3: Color(0xFF92A19C),
    line: Color(0xFF25312F),
    line2: Color(0xFF37453F),
    hero: Color(0xFF0F4A44),
    pri: Color(0xFF7AD8CC),
    onPri: Color(0xFF06231F),
    priT: Color(0xFF173A36),
    priInk: Color(0xFFBFEAE3),
    amb: Color(0xFFF2C46B),
    ambT: Color(0xFF3A2D0E),
    ambBar: Color(0xFFD9A441),
    ok: Color(0xFF7FD6A4),
    okT: Color(0xFF12301F),
    bad: Color(0xFFFF9C92),
    badT: Color(0xFF3A1714),
    heroShadow: Color(0x00000000),
  );

  final Color bg;
  final Color sf;
  final Color sf2;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color line;
  final Color line2;
  final Color hero;
  final Color pri;
  final Color onPri;
  final Color priT;
  final Color priInk;
  final Color amb;
  final Color ambT;
  final Color ambBar;
  final Color ok;
  final Color okT;
  final Color bad;
  final Color badT;
  final Color heroShadow;

  @override
  KhColors copyWith() => this;

  @override
  KhColors lerp(ThemeExtension<KhColors>? other, double t) => this;
}

extension KhContext on BuildContext {
  KhColors get kh => Theme.of(this).extension<KhColors>()!;
}

/// Thang chữ của thiết kế (`k-d1` … `k-code`). Màu do widget đặt (theo `KhColors`).
abstract final class KhType {
  static const d1 = TextStyle(
    fontSize: 34,
    height: 40 / 34,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );
  static const d2 = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.28,
  );
  static const t1 = TextStyle(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
  );
  static const t2 = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );
  static const b = TextStyle(fontSize: 15, height: 22 / 15);
  static const s = TextStyle(fontSize: 13, height: 18 / 13);
  static const c = TextStyle(fontSize: 12, height: 16 / 12);
  static const code = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.72,
  );
  static const nums = [FontFeature.tabularFigures()];
}

ThemeData buildKhTheme(Brightness brightness) {
  final k = brightness == Brightness.dark ? KhColors.dark : KhColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: k.pri,
    onPrimary: k.onPri,
    primaryContainer: k.priT,
    onPrimaryContainer: k.priInk,
    secondary: k.pri,
    onSecondary: k.onPri,
    secondaryContainer: k.priT,
    onSecondaryContainer: k.priInk,
    error: k.bad,
    onError: k.onPri,
    errorContainer: k.badT,
    onErrorContainer: k.bad,
    surface: k.bg,
    onSurface: k.ink,
    onSurfaceVariant: k.ink2,
    outline: k.line2,
    outlineVariant: k.line,
    surfaceContainerLowest: k.sf,
    surfaceContainerLow: k.sf,
    surfaceContainer: k.sf,
    surfaceContainerHigh: k.sf2,
    surfaceContainerHighest: k.sf2,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'BeVietnamPro',
    colorScheme: scheme,
    scaffoldBackgroundColor: k.bg,
    // Các widget lõi dùng chung (ErrorState…) đọc ToneColors.
    extensions: [
      k,
      if (brightness == Brightness.dark) ToneColors.dark else ToneColors.light,
    ],
    textTheme: Typography.material2021().black.apply(
      fontFamily: 'BeVietnamPro',
      bodyColor: k.ink,
      displayColor: k.ink,
    ),
    splashFactory: InkRipple.splashFactory,
    dividerColor: k.line,
    dialogTheme: DialogThemeData(
      backgroundColor: k.sf,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: KhType.t1.copyWith(
        color: k.ink,
        fontFamily: 'BeVietnamPro',
      ),
      contentTextStyle: KhType.b.copyWith(
        color: k.ink2,
        fontFamily: 'BeVietnamPro',
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: k.bg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: k.ink,
      contentTextStyle: KhType.s.copyWith(
        color: k.bg,
        fontFamily: 'BeVietnamPro',
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: k.pri),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? k.pri : k.sf2,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? k.pri : k.line2,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? k.onPri : k.ink3,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: k.pri),
    ),
  );
}
