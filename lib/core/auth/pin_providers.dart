import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pin_service.dart';
import 'providers.dart';

/// Tài khoản hiện tại đã đặt PIN trên thiết bị này chưa.
class PinEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthSignedIn) return false;
    return await ref.read(pinServiceProvider).isSet(auth.user.id);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final pinEnabledProvider = AsyncNotifierProvider<PinEnabledNotifier, bool>(
  PinEnabledNotifier.new,
);
