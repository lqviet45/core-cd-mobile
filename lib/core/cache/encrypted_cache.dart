import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'blob_store.dart';

/// Cung cấp khoá AES-256 của bộ nhớ đệm. Khoá nằm ở nơi an toàn của hệ điều hành, tách khỏi dữ liệu.
abstract interface class CacheKeyProvider {
  Future<List<int>> key();

  /// Huỷ khoá: dữ liệu cũ (nếu còn sót) không thể giải mã nữa.
  Future<void> destroy();
}

class SecureCacheKeyProvider implements CacheKeyProvider {
  SecureCacheKeyProvider([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _name = 'core_cd.cache_key';
  final FlutterSecureStorage _storage;

  @override
  Future<List<int>> key() async {
    final saved = await _storage.read(key: _name);
    if (saved != null) return base64Decode(saved);
    final rng = Random.secure();
    final fresh = List<int>.generate(32, (_) => rng.nextInt(256));
    await _storage.write(key: _name, value: base64Encode(fresh));
    return fresh;
  }

  @override
  Future<void> destroy() => _storage.delete(key: _name);
}

/// Khoá cố định trong bộ nhớ: dùng cho test.
class FixedCacheKeyProvider implements CacheKeyProvider {
  FixedCacheKeyProvider(this._key);
  List<int> _key;

  @override
  Future<List<int>> key() async => _key;

  @override
  Future<void> destroy() async => _key = List<int>.filled(32, 0);
}

/// Một bản ghi đệm: nội dung JSON gốc và thời điểm lưu.
class CachedEntry {
  const CachedEntry({required this.body, required this.savedAt});
  final String body;
  final DateTime savedAt;
}

/// Đệm các phản hồi đọc **mã hoá AES-256-GCM**. Tên tệp là băm SHA-256 của khoá logic (URL có thể chứa tên/CIF),
/// khoá logic cũng được gắn vào dữ liệu xác thực (AAD) nên không thể hoán đổi tệp giữa các mục. Mọi lỗi giải mã
/// (sai khoá, tệp bị sửa/hỏng) đều coi như không có bản đệm, không ném lỗi.
class EncryptedCache {
  EncryptedCache(this._blobs, this._keys, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final BlobStore _blobs;
  final CacheKeyProvider _keys;
  final DateTime Function() _now;
  final _aes = AesGcm.with256bits();

  static Future<String> blobName(String logicalKey) async {
    final h = await Sha256().hash(utf8.encode(logicalKey));
    return h.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> write(String logicalKey, String body) async {
    final secret = SecretKey(await _keys.key());
    final payload = jsonEncode({
      't': _now().toUtc().toIso8601String(),
      'b': body,
    });
    final box = await _aes.encrypt(
      utf8.encode(payload),
      secretKey: secret,
      aad: utf8.encode(logicalKey),
    );
    await _blobs.write(
      await blobName(logicalKey),
      Uint8List.fromList(box.concatenation()),
    );
  }

  /// `null` nếu không có, quá [maxAge], hoặc không giải mã được.
  Future<CachedEntry?> read(
    String logicalKey, {
    required Duration maxAge,
  }) async {
    final name = await blobName(logicalKey);
    final bytes = await _blobs.read(name);
    if (bytes == null) return null;
    try {
      final secret = SecretKey(await _keys.key());
      final box = SecretBox.fromConcatenation(
        bytes,
        nonceLength: _aes.nonceLength,
        macLength: _aes.macAlgorithm.macLength,
      );
      final clear = await _aes.decrypt(
        box,
        secretKey: secret,
        aad: utf8.encode(logicalKey),
      );
      final m = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      final saved = DateTime.parse(m['t'] as String);
      if (_now().difference(saved) > maxAge) {
        await _blobs.delete(name);
        return null;
      }
      return CachedEntry(body: m['b'] as String, savedAt: saved);
    } on Object {
      return null;
    }
  }

  /// Xoá toàn bộ dữ liệu đệm và huỷ khoá (khi đăng xuất).
  Future<void> clear() async {
    await _blobs.clear();
    await _keys.destroy();
  }
}
