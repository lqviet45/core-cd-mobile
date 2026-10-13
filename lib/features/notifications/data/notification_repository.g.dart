// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_repository.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      severity: json['severity'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: const UtcDateConverter().fromJson(json['createdAt'] as String),
      isRead: json['isRead'] as bool,
      linkUrl: json['linkUrl'] as String?,
    );
