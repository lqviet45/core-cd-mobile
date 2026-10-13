import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../core/models/paged.dart';
import '../../../core/network/api_call.dart';
import '../../../core/utils/json_converters.dart';

part 'notification_repository.g.dart';

@JsonSerializable(createToJson: false)
@UtcDateConverter()
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.linkUrl,
  });
  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  final String id;
  final String type;
  final String severity;
  final String title;
  final String body;
  final String? linkUrl;
  final DateTime createdAt;
  final bool isRead;
}

class NotificationRepository {
  NotificationRepository(this._dio);
  final Dio _dio;

  Future<Paged<AppNotification>> list({
    int page = 1,
    int pageSize = 20,
    bool unreadOnly = false,
  }) => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/notifications',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
        'unreadOnly': unreadOnly,
      },
    );
    return Paged.fromJson(res.data!, AppNotification.fromJson);
  });

  Future<int> unreadCount() => apiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/notifications/unread-count',
    );
    return res.data!['count'] as int;
  });

  /// Danh sách rỗng/`null` = đánh dấu tất cả. Trả số thông báo vừa đánh dấu.
  Future<int> markRead([List<String>? ids]) => apiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/notifications/mark-read',
      data: {'ids': ids},
    );
    return res.data!['marked'] as int;
  });
}
