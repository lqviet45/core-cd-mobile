import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences` đã khởi tạo: ghi đè trong `main()`/test. Chỉ lưu tuỳ chọn không nhạy cảm
/// (giao diện, thời gian tự khoá…); token và khoá nằm ở secure storage.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider chưa được ghi đè'),
);

/// Tuỳ chọn của người dùng trên thiết bị này.
@immutable
class AppPrefs {
  const AppPrefs({
    this.themeMode = ThemeMode.system,
    this.lockEnabled = true,
    this.lockAfter = const Duration(minutes: 1),
    this.hideAmounts = false,
  });

  final ThemeMode themeMode;

  /// Khoá nhanh khi mở app / quay lại từ nền. Các thao tác tiền luôn yêu cầu xác thực riêng, bất kể cài đặt này.
  final bool lockEnabled;
  final Duration lockAfter;

  /// Ẩn số tiền ở màn Tổng quan (dùng nơi đông người).
  final bool hideAmounts;

  static const lockChoices = [
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  AppPrefs copyWith({
    ThemeMode? themeMode,
    bool? lockEnabled,
    Duration? lockAfter,
    bool? hideAmounts,
  }) => AppPrefs(
    themeMode: themeMode ?? this.themeMode,
    lockEnabled: lockEnabled ?? this.lockEnabled,
    lockAfter: lockAfter ?? this.lockAfter,
    hideAmounts: hideAmounts ?? this.hideAmounts,
  );
}

class AppPrefsNotifier extends Notifier<AppPrefs> {
  static const _theme = 'pref.theme';
  static const _lock = 'pref.lock_enabled';
  static const _lockSecs = 'pref.lock_after_secs';
  static const _hide = 'pref.hide_amounts';

  SharedPreferences get _p => ref.read(sharedPrefsProvider);

  @override
  AppPrefs build() {
    final p = ref.watch(sharedPrefsProvider);
    final secs = p.getInt(_lockSecs);
    return AppPrefs(
      themeMode: switch (p.getString(_theme)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      lockEnabled: p.getBool(_lock) ?? true,
      lockAfter: Duration(seconds: secs ?? 60),
      hideAmounts: p.getBool(_hide) ?? false,
    );
  }

  Future<void> setThemeMode(ThemeMode m) async {
    state = state.copyWith(themeMode: m);
    await _p.setString(_theme, m.name);
  }

  Future<void> setLockEnabled(bool v) async {
    state = state.copyWith(lockEnabled: v);
    await _p.setBool(_lock, v);
  }

  Future<void> setLockAfter(Duration d) async {
    state = state.copyWith(lockAfter: d);
    await _p.setInt(_lockSecs, d.inSeconds);
  }

  Future<void> setHideAmounts(bool v) async {
    state = state.copyWith(hideAmounts: v);
    await _p.setBool(_hide, v);
  }
}

final appPrefsProvider = NotifierProvider<AppPrefsNotifier, AppPrefs>(
  AppPrefsNotifier.new,
);
