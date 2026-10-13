import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/api_providers.dart';
import '../data/document_dto.dart';
import 'document_io.dart';

/// Khoá `(ownerType, ownerId)`; record có so sánh theo giá trị nên dùng được làm khoá family.
typedef DocumentOwner = ({String type, String id});

final documentsProvider = FutureProvider.autoDispose
    .family<List<DocumentItem>, DocumentOwner>(
      (ref, o) => ref.watch(documentRepositoryProvider).list(o.type, o.id),
    );

/// Có thể ghi đè trong test để không gọi plugin nền tảng.
final documentOpenerProvider = Provider<DocumentOpener>(
  (_) => const PlatformDocumentOpener(),
);
final imageSourcePickerProvider = Provider<ImageSourcePicker>(
  (_) => PlatformImagePicker(),
);
