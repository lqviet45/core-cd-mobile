import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/document_dto.dart';

/// Mở/chia sẻ tệp ra ngoài app. Tách giao diện để test không cần plugin nền tảng.
abstract interface class DocumentOpener {
  /// Mở URL ngắn hạn bằng trình duyệt/ứng dụng xem PDF của hệ thống.
  Future<bool> open(String url);

  /// Chia sẻ nội dung tệp (chọn ứng dụng nhận). Tệp tạm được xoá ngay sau đó.
  Future<void> share(String fileName, List<int> bytes, String contentType);
}

class PlatformDocumentOpener implements DocumentOpener {
  const PlatformDocumentOpener();

  @override
  Future<bool> open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Future<void> share(
    String fileName,
    List<int> bytes,
    String contentType,
  ) async {
    if (kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(bytes),
              mimeType: contentType,
              name: fileName,
            ),
          ],
        ),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    // Tên tệp do máy chủ cấp: chỉ lấy phần tên, tránh lên thư mục cha.
    final file = File(p.join(dir.path, p.basename(fileName)));
    await file.writeAsBytes(bytes, flush: true);
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: contentType)]),
      );
    } finally {
      if (file.existsSync()) await file.delete();
    }
  }
}

/// Chụp/chọn ảnh giấy tờ. Trả `null` nếu người dùng huỷ.
abstract interface class ImageSourcePicker {
  Future<UploadFile?> pick({required bool camera});
}

class PlatformImagePicker implements ImageSourcePicker {
  PlatformImagePicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<UploadFile?> pick({required bool camera}) async {
    final x = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      // Giảm dung lượng trước khi tải lên (ảnh CCCD không cần độ phân giải của camera).
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    final mime =
        x.mimeType ??
        (x.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    return UploadFile(name: x.name, contentType: mime, bytes: bytes);
  }
}
