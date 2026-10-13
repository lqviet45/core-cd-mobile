import 'dart:async';

import 'package:core_cd_mobile/core/push/push_token_source.dart';
import 'package:core_cd_mobile/features/documents/data/document_dto.dart';
import 'package:core_cd_mobile/features/documents/presentation/document_io.dart';

class FakePushTokenSource implements PushTokenSource {
  FakePushTokenSource([this.token]);
  String? token;
  int deleted = 0;
  final _refresh = StreamController<String>.broadcast();
  final _tap = StreamController<Map<String, String>>.broadcast();

  @override
  Future<String?> currentToken() async => token;

  @override
  Stream<String> get onTokenRefresh => _refresh.stream;

  @override
  Stream<Map<String, String>> get onNotificationTap => _tap.stream;

  @override
  Future<void> deleteToken() async => deleted++;

  void refresh(String t) => _refresh.add(t);
  void tap(Map<String, String> data) => _tap.add(data);
}

class FakeOpener implements DocumentOpener {
  final opened = <String>[];
  final shared = <({String name, List<int> bytes, String type})>[];
  bool canOpen = true;

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return canOpen;
  }

  @override
  Future<void> share(
    String fileName,
    List<int> bytes,
    String contentType,
  ) async {
    shared.add((name: fileName, bytes: bytes, type: contentType));
  }
}

class FakePicker implements ImageSourcePicker {
  UploadFile? next;
  final calls = <bool>[];

  @override
  Future<UploadFile?> pick({required bool camera}) async {
    calls.add(camera);
    return next;
  }
}
