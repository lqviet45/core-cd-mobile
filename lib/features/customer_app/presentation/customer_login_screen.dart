import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/providers.dart';
import '../../../core/network/api_exception.dart';
import 'customer_providers.dart';
import 'kh_theme.dart';
import 'kh_widgets.dart';

/// K01 – Đăng nhập bằng số điện thoại hoặc mã khách hàng + mật khẩu; có phiên đã lưu và bật sinh trắc thì mở nhanh
/// bằng vân tay / Face ID. Mật khẩu lần đầu do nhân viên cấp (xem màn đổi mật khẩu bắt buộc).
class CustomerLoginScreen extends ConsumerStatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  ConsumerState<CustomerLoginScreen> createState() => _State();
}

class _State extends ConsumerState<CustomerLoginScreen> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _autoPrompted = false;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _id.text.trim();
    if (id.isEmpty || _password.text.isEmpty) {
      setState(
        () => _error = 'Nhập số điện thoại hoặc mã khách hàng và mật khẩu.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Router tự chuyển sang màn chính (hoặc màn đổi mật khẩu bắt buộc) khi đăng nhập xong.
      await ref
          .read(custAuthControllerProvider.notifier)
          .login(id, _password.text);
    } on ApiException catch (e) {
      if (mounted) {
        setState(
          () => _error = e.status == 429
              ? 'Thử đăng nhập quá nhiều lần. Vui lòng chờ một phút.'
              : e.message,
        );
      }
    } on Object {
      if (mounted) setState(() => _error = 'Có lỗi xảy ra. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _biometric() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await ref
          .read(custAuthControllerProvider.notifier)
          .unlockWithBiometric();
      if (!ok && mounted) {
        setState(
          () => _error =
              'Chưa xác thực được. Hãy thử lại hoặc đăng nhập bằng mật khẩu.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final k = ctx.kh;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quên mật khẩu?', style: KhType.t1.copyWith(color: k.ink)),
                const SizedBox(height: 8),
                Text(
                  'Vì an toàn, mật khẩu chỉ được cấp lại trực tiếp. Vui lòng đến chi nhánh hoặc liên hệ chuyên viên của bạn. '
                  'Nhân viên sẽ cấp mật khẩu tạm và bạn sẽ được yêu cầu đổi ngay khi đăng nhập.',
                  style: KhType.b.copyWith(color: k.ink2),
                ),
                const SizedBox(height: 20),
                KhButton(label: 'Đã hiểu', onPressed: () => Navigator.pop(ctx)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    final auth = ref.watch(custAuthControllerProvider);
    final expired = auth is AuthSignedOut && auth.expired;
    final bioReady = ref.watch(custBiometricReadyProvider);
    if (bioReady && !_autoPrompted) {
      _autoPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_biometric());
      });
    }

    return Scaffold(
      backgroundColor: k.bg,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KhHero(
              shadow: false,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(36),
              ),
              padding: EdgeInsets.fromLTRB(
                28,
                MediaQuery.paddingOf(context).top + 56,
                28,
                36,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0x24FFFFFF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      LucideIcons.landmark,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Semantics(
                    header: true,
                    child: Text(
                      'Tiền gửi của bạn,\nrõ ràng trong tầm tay.',
                      style: KhType.d2.copyWith(
                        fontSize: 30,
                        height: 38 / 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Theo dõi chứng chỉ tiền gửi, lãi và ngày đáo hạn mọi lúc.',
                    style: KhType.b.copyWith(color: const Color(0xCCFFFFFF)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (expired) ...[
                      const KhNote(
                        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
                        icon: LucideIcons.clock,
                        amber: true,
                      ),
                      const SizedBox(height: 18),
                    ],
                    KhField(
                      key: const Key('identifier'),
                      label: 'Số điện thoại hoặc mã khách hàng',
                      controller: _id,
                      icon: LucideIcons.user,
                      enabled: !_busy,
                      keyboardType: TextInputType.text,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 18),
                    KhField(
                      key: const Key('password'),
                      label: 'Mật khẩu',
                      controller: _password,
                      icon: LucideIcons.lock,
                      obscure: true,
                      enabled: !_busy,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Semantics(
                        liveRegion: true,
                        child: KhNote(
                          _error!,
                          icon: LucideIcons.circleAlert,
                          amber: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    KhButton(
                      label: 'Đăng nhập',
                      onPressed: _busy ? null : _submit,
                      busy: _busy,
                    ),
                    if (bioReady) ...[
                      const SizedBox(height: 12),
                      KhButton(
                        label: 'Đăng nhập bằng vân tay / Face ID',
                        icon: LucideIcons.fingerprintPattern,
                        kind: KhButtonKind.outlined,
                        height: 48,
                        onPressed: _busy ? null : _biometric,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _forgot,
                        child: const Text(
                          'Quên mật khẩu?',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cần hỗ trợ? Liên hệ chuyên viên hoặc chi nhánh của bạn.',
                      textAlign: TextAlign.center,
                      style: KhType.c.copyWith(color: k.ink3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
