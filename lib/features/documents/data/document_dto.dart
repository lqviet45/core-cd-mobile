import 'package:json_annotation/json_annotation.dart';

import '../../../core/utils/json_converters.dart';

part 'document_dto.g.dart';

/// Tài liệu của một đối tượng (hợp đồng, chứng chỉ PDF, hồ sơ KYC…). Nội dung nằm ở kho tệp; app chỉ nhận
/// URL ngắn hạn do API cấp mỗi lần tải.
@JsonSerializable(createToJson: false)
@UtcDateConverter()
class DocumentItem {
  const DocumentItem({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.kind,
    required this.status,
    required this.version,
    required this.fileName,
    required this.contentType,
    required this.size,
    required this.createdAt,
    this.createdBy,
  });
  factory DocumentItem.fromJson(Map<String, dynamic> json) =>
      _$DocumentItemFromJson(json);

  final String id;

  /// `Transaction | Certificate | Customer`.
  final String ownerType;
  final String ownerId;

  /// `TradeContract | SignedContract | CertificatePdf | KycIdentity | KycBusinessLicense | Other`.
  final String kind;

  /// `Pending | Available`.
  final String status;
  final int version;
  final String fileName;
  final String contentType;
  final int size;
  final DateTime createdAt;
  final String? createdBy;

  bool get isAvailable => status == 'Available';
}

String documentKindLabel(String kind) => switch (kind) {
  'TradeContract' => 'Hợp đồng',
  'SignedContract' => 'Bản đã ký',
  'CertificatePdf' => 'Chứng chỉ (PDF)',
  'KycIdentity' => 'Giấy tờ định danh',
  'KycBusinessLicense' => 'Giấy đăng ký kinh doanh',
  _ => 'Tài liệu khác',
};

@JsonSerializable(createToJson: false)
class DownloadLink {
  const DownloadLink({required this.url, required this.fileName});
  factory DownloadLink.fromJson(Map<String, dynamic> json) =>
      _$DownloadLinkFromJson(json);

  /// URL ngắn hạn (≤ 5 phút): không lưu, không ghi log.
  final String url;
  final String fileName;
}

@JsonSerializable(createToJson: false)
class UploadRequest {
  const UploadRequest({
    required this.documentId,
    required this.uploadUrl,
    required this.contentType,
    required this.maxBytes,
  });
  factory UploadRequest.fromJson(Map<String, dynamic> json) =>
      _$UploadRequestFromJson(json);

  final String documentId;
  final String uploadUrl;
  final String contentType;
  final int maxBytes;
}

/// Tệp ảnh người dùng vừa chụp/chọn, giữ trong bộ nhớ (không ghi ra thư viện ảnh).
class UploadFile {
  const UploadFile({
    required this.name,
    required this.contentType,
    required this.bytes,
  });
  final String name;
  final String contentType;
  final List<int> bytes;
}
