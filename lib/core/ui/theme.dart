import 'package:flutter/material.dart';

import '../utils/labels.dart';

/// Design tokens của app mobile, lấy từ canvas thiết kế "Core CD – Thiết kế Web & Mobile (Flutter)"
/// (`mob.css`: Material 3, nền teal nhạt, sáng/tối).
abstract final class Tokens {
  static const radiusCard = 16.0;
  static const radiusChip = 8.0;
  static const gap = 16.0;
  static const gapSm = 8.0;

  /// Màu cảnh báo của thanh tiến độ khi sắp đáo hạn/sắp hết hạn mức (`.m-pr.w`).
  static const warnBar = Color(0xFFC77700);
}

/// Các màu ngoài bộ M3 chuẩn: container cho trạng thái thành công/cảnh báo.
@immutable
class ToneColors extends ThemeExtension<ToneColors> {
  const ToneColors({
    required this.okContainer,
    required this.onOk,
    required this.warnContainer,
    required this.onWarn,
    required this.errorContainer,
    required this.onError,
    required this.infoContainer,
    required this.onInfo,
    required this.neutralContainer,
    required this.onNeutral,
  });

  static const light = ToneColors(
    okContainer: Color(0xFFC8F0D0),
    onOk: Color(0xFF00391A),
    warnContainer: Color(0xFFFFE9B8),
    onWarn: Color(0xFF5C4300),
    errorContainer: Color(0xFFFFDAD6),
    onError: Color(0xFFBA1A1A),
    infoContainer: Color(0xFFCCE8E3),
    onInfo: Color(0xFF06201D),
    neutralContainer: Color(0xFFDFE4E2),
    onNeutral: Color(0xFF3F4947),
  );

  static const dark = ToneColors(
    okContainer: Color(0xFF0A3D1F),
    onOk: Color(0xFFC8F0D0),
    warnContainer: Color(0xFF4A3800),
    onWarn: Color(0xFFFFE9B8),
    errorContainer: Color(0xFF93000A),
    onError: Color(0xFFFFB4AB),
    infoContainer: Color(0xFF344B48),
    onInfo: Color(0xFFCCE8E3),
    neutralContainer: Color(0xFF303636),
    onNeutral: Color(0xFFBEC9C6),
  );

  final Color okContainer;
  final Color onOk;
  final Color warnContainer;
  final Color onWarn;
  final Color errorContainer;
  final Color onError;
  final Color infoContainer;
  final Color onInfo;
  final Color neutralContainer;
  final Color onNeutral;

  Color bg(Tone t) => switch (t) {
    Tone.success => okContainer,
    Tone.warning => warnContainer,
    Tone.danger => errorContainer,
    Tone.info => infoContainer,
    Tone.neutral => neutralContainer,
  };

  Color fg(Tone t) => switch (t) {
    Tone.success => onOk,
    Tone.warning => onWarn,
    Tone.danger => onError,
    Tone.info => onInfo,
    Tone.neutral => onNeutral,
  };

  @override
  ToneColors copyWith() => this;

  @override
  ToneColors lerp(ThemeExtension<ToneColors>? other, double t) => this;
}

extension ToneColorsContext on BuildContext {
  ToneColors get tones => Theme.of(this).extension<ToneColors>()!;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

/// Màu cho biểu đồ (cùng bảng với web).
List<Color> chartColors(Brightness b) => b == Brightness.dark
    ? const [
        Color(0xFF6FD8CC),
        Color(0xFF60A5FA),
        Color(0xFFFBBF24),
        Color(0xFFA78BFA),
        Color(0xFFF472B6),
      ]
    : const [
        Color(0xFF0F766E),
        Color(0xFF2563EB),
        Color(0xFFD97706),
        Color(0xFF7C3AED),
        Color(0xFFDB2777),
      ];

ColorScheme _scheme(Brightness b) {
  if (b == Brightness.dark) {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF6FD8CC),
      onPrimary: Color(0xFF003732),
      primaryContainer: Color(0xFF00504A),
      onPrimaryContainer: Color(0xFFB9F0E8),
      secondary: Color(0xFFB0CCC7),
      onSecondary: Color(0xFF1B3532),
      secondaryContainer: Color(0xFF344B48),
      onSecondaryContainer: Color(0xFFCCE8E3),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF0E1514),
      onSurface: Color(0xFFDEE4E2),
      onSurfaceVariant: Color(0xFFBEC9C6),
      outline: Color(0xFF899390),
      outlineVariant: Color(0xFF3F4947),
      surfaceContainerLowest: Color(0xFF0E1514),
      surfaceContainerLow: Color(0xFF161D1C),
      surfaceContainer: Color(0xFF1A2120),
      surfaceContainerHigh: Color(0xFF252B2B),
      surfaceContainerHighest: Color(0xFF303636),
    );
  }
  return const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0F766E),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFB9F0E8),
    onPrimaryContainer: Color(0xFF00201D),
    secondary: Color(0xFF4A6360),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFCCE8E3),
    onSecondaryContainer: Color(0xFF06201D),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFF6FAF8),
    onSurface: Color(0xFF171D1C),
    onSurfaceVariant: Color(0xFF3F4947),
    outline: Color(0xFF6F7977),
    outlineVariant: Color(0xFFBEC9C6),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF0F5F3),
    surfaceContainer: Color(0xFFEAEFED),
    surfaceContainerHigh: Color(0xFFE4E9E7),
    surfaceContainerHighest: Color(0xFFDFE4E2),
  );
}

ThemeData buildTheme(Brightness brightness) {
  final s = _scheme(brightness);
  final dark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: s,
    scaffoldBackgroundColor: s.surface,
    extensions: [if (dark) ToneColors.dark else ToneColors.light],
    // Chữ theo thang M3 của thiết kế (headline 24, title 22/16/14, body 16/14/12).
    textTheme: const TextTheme(
      displayMedium: TextStyle(
        fontSize: 36,
        height: 44 / 36,
        fontWeight: FontWeight.w400,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w400,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w400,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w400,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 24 / 16),
      bodyMedium: TextStyle(fontSize: 14, height: 20 / 14),
      bodySmall: TextStyle(fontSize: 12, height: 16 / 12),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: s.surface,
      foregroundColor: s.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        height: 28 / 22,
        color: s.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: s.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: s.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: s.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: s.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: s.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: s.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        shape: const StadiumBorder(),
        side: BorderSide(color: s.outline),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: s.surfaceContainer,
      indicatorColor: s.secondaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: s.onSurfaceVariant,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: s.inverseSurface,
      contentTextStyle: TextStyle(color: s.onInverseSurface),
    ),
    // Vùng chạm tối thiểu 48dp cho thao tác chính.
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
