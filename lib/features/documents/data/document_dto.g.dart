// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DocumentItem _$DocumentItemFromJson(Map<String, dynamic> json) => DocumentItem(
  id: json['id'] as String,
  ownerType: json['ownerType'] as String,
  ownerId: json['ownerId'] as String,
  kind: json['kind'] as String,
  status: json['status'] as String,
  version: (json['version'] as num).toInt(),
  fileName: json['fileName'] as String,
  contentType: json['contentType'] as String,
  size: (json['size'] as num).toInt(),
  createdAt: const UtcDateConverter().fromJson(json['createdAt'] as String),
  createdBy: json['createdBy'] as String?,
);

DownloadLink _$DownloadLinkFromJson(Map<String, dynamic> json) => DownloadLink(
  url: json['url'] as String,
  fileName: json['fileName'] as String,
);

UploadRequest _$UploadRequestFromJson(Map<String, dynamic> json) =>
    UploadRequest(
      documentId: json['documentId'] as String,
      uploadUrl: json['uploadUrl'] as String,
      contentType: json['contentType'] as String,
      maxBytes: (json['maxBytes'] as num).toInt(),
    );
