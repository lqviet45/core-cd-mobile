import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Nơi lưu các khối byte theo tên (đã được mã hoá ở lớp trên; ở đây không biết nội dung).
abstract interface class BlobStore {
  Future<Uint8List?> read(String name);
  Future<void> write(String name, Uint8List bytes);
  Future<void> delete(String name);
  Future<void> clear();
}

/// Lưu trong bộ nhớ: dùng cho web (không có hệ thống tệp riêng của app) và cho test.
class MemoryBlobStore implements BlobStore {
  final Map<String, Uint8List> _m = {};

  /// Cho test: xem tên khối đang lưu.
  Iterable<String> get names => _m.keys;

  Uint8List? raw(String name) => _m[name];

  @override
  Future<Uint8List?> read(String name) async => _m[name];

  @override
  Future<void> write(String name, Uint8List bytes) async => _m[name] = bytes;

  @override
  Future<void> delete(String name) async => _m.remove(name);

  @override
  Future<void> clear() async => _m.clear();
}

/// Lưu thành tệp trong thư mục hỗ trợ riêng của app (không nằm trong thư viện ảnh/tài liệu người dùng thấy được).
class FileBlobStore implements BlobStore {
  FileBlobStore({Future<Directory> Function()? root, this.folder = 'api_cache'})
    : _root = root ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _root;
  final String folder;
  Directory? _dir;

  Future<Directory> _ensure() async {
    final existing = _dir;
    if (existing != null) return existing;
    final base = await _root();
    final d = Directory(p.join(base.path, folder));
    if (!d.existsSync()) await d.create(recursive: true);
    return _dir = d;
  }

  Future<File> _file(String name) async =>
      File(p.join((await _ensure()).path, name));

  @override
  Future<Uint8List?> read(String name) async {
    final f = await _file(name);
    return f.existsSync() ? await f.readAsBytes() : null;
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    final f = await _file(name);
    // Ghi ra tệp tạm rồi đổi tên: app bị tắt giữa chừng không để lại tệp hỏng.
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> delete(String name) async {
    final f = await _file(name);
    if (f.existsSync()) await f.delete();
  }

  @override
  Future<void> clear() async {
    final d = await _ensure();
    if (d.existsSync()) await d.delete(recursive: true);
    _dir = null;
  }
}
