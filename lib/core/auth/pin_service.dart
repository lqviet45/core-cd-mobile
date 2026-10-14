import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Nơi lưu băm PIN và bộ đếm thử sai (secure storage). Tách giao diện để test không cần plugin.
abstract interface class PinStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecurePinStorage implements PinStorage {
  SecurePinStorage([FlutterSecureStorage? s])
    : _s = s ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) => _s.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

class InMemoryPinStorage implements PinStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);
}

const pinLength = 6;

/// `null` nếu PIN đủ mạnh, ngược lại là lý do (để hiện cho người dùng).
String? pinProblem(String pin) {
  if (!RegExp('^\\d{$pinLength}\$').hasMatch(pin)) {
    return 'PIN gồm đúng $pinLength chữ số.';
  }
  if (pin.split('').toSet().length == 1) {
    return 'PIN không được gồm các số giống nhau.';
  }
  final d = pin.codeUnits;
  final up = [for (var i = 1; i < d.length; i++) d[i] - d[i - 1]];
  if (up.every((x) => x == 1) || up.every((x) => x == -1)) {
    return 'PIN không được là dãy số liên tiếp.';
  }
  return null;
}

sealed class PinResult {
  const PinResult();
}

class PinOk extends PinResult {
  const PinOk();
}

class PinWrong extends PinResult {
  const PinWrong(this.attemptsLeft);
  final int attemptsLeft;
}

/// Hết lượt thử: PIN đã bị xoá, người dùng phải đăng nhập lại bằng mật khẩu.
class PinLockedOut extends PinResult {
  const PinLockedOut();
}

/// PIN 6 số mở khoá app, **theo từng tài khoản trên thiết bị này**.
///
/// - Chỉ lưu băm PBKDF2-HMAC-SHA256 có muối ngẫu nhiên (không lưu PIN).
/// - Số lần thử sai lưu bền: tắt/mở app không làm đếm lại. Sai [maxAttempts] lần → xoá PIN và buộc đăng nhập lại.
/// - PIN chỉ mở khoá app; thao tác tiền vẫn cần sinh trắc/mã khoá thiết bị (xem `MoneyGate`).
class PinService {
  PinService(this._storage, {this.iterations = 100000, this.maxAttempts = 5});
  final PinStorage _storage;
  final int iterations;
  final int maxAttempts;

  static String _pinKey(String uid) => 'core_cd.pin.$uid';
  static String _attemptsKey(String uid) => 'core_cd.pin_attempts.$uid';

  /// Lỗi đọc secure storage (Keystore hỏng…) coi như chưa đặt PIN: khoá nhanh rơi về sinh trắc/mã thiết bị.
  Future<bool> isSet(String userId) async {
    try {
      return await _storage.read(_pinKey(userId)) != null;
    } on Object {
      return false;
    }
  }

  Future<List<int>> _hash(String pin, List<int> salt, int iter) async {
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iter,
      bits: 256,
    ).deriveKeyFromPassword(password: pin, nonce: salt);
    return await key.extractBytes();
  }

  /// Đặt (hoặc đổi) PIN. Ném [ArgumentError] nếu PIN không hợp lệ.
  Future<void> set(String userId, String pin) async {
    final problem = pinProblem(pin);
    if (problem != null) throw ArgumentError(problem);
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final h = await _hash(pin, salt, iterations);
    await _storage.write(
      _pinKey(userId),
      jsonEncode({
        's': base64Encode(salt),
        'h': base64Encode(h),
        'i': iterations,
      }),
    );
    await _storage.delete(_attemptsKey(userId));
  }

  Future<int> _attempts(String userId) async =>
      int.tryParse(await _storage.read(_attemptsKey(userId)) ?? '') ?? 0;

  Future<PinResult> verify(String userId, String pin) async {
    final raw = await _storage.read(_pinKey(userId));
    if (raw == null) return const PinLockedOut();
    final used = await _attempts(userId);
    if (used >= maxAttempts) {
      await clear(userId);
      return const PinLockedOut();
    }
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final expected = base64Decode(m['h'] as String);
    final actual = await _hash(
      pin,
      base64Decode(m['s'] as String),
      m['i'] as int,
    );
    if (_constantTimeEquals(expected, actual)) {
      await _storage.delete(_attemptsKey(userId));
      return const PinOk();
    }
    final now = used + 1;
    if (now >= maxAttempts) {
      await clear(userId);
      return const PinLockedOut();
    }
    await _storage.write(_attemptsKey(userId), '$now');
    return PinWrong(maxAttempts - now);
  }

  Future<void> clear(String userId) async {
    await _storage.delete(_pinKey(userId));
    await _storage.delete(_attemptsKey(userId));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

final pinStorageProvider = Provider<PinStorage>((ref) => SecurePinStorage());

final pinServiceProvider = Provider<PinService>(
  (ref) => PinService(ref.watch(pinStorageProvider)),
);
