import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/providers.dart';
import '../../../core/ui/theme.dart';
import '../../../core/utils/labels.dart';
import 'customer_providers.dart';

/// Đăng nhập bằng số điện thoại + mã OTP. Chỉ khách đã được ngân hàng bật quyền mới nhận được mã;
/// màn hình **không** tiết lộ số có tài khoản hay không (máy chủ trả cùng một kết quả).
class CustomerLoginScreen extends ConsumerStatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  ConsumerState<CustomerLoginScreen> createState() => _State();
}

class _State extends ConsumerState<CustomerLoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _codeStep = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) t.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = e is _Invalid ? e.message : loginErrorText(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() => _run(() async {
    final phone = _phone.text.trim();
    if (phone.length < 9) {
      throw const _Invalid('Nhập số điện thoại di động đã đăng ký.');
    }
    final r = await ref
        .read(custAuthControllerProvider.notifier)
        .requestOtp(phone);
    if (!mounted) return;
    setState(() => _codeStep = true);
    _startCountdown(r.resendAfterSeconds);
  });

  Future<void> _verify() => _run(() async {
    final code = _code.text.trim();
    if (code.length != 6) throw const _Invalid('Nhập đủ 6 chữ số của mã OTP.');
    // Router tự chuyển sang màn chính khi đăng nhập xong.
    await ref
        .read(custAuthControllerProvider.notifier)
        .verifyOtp(_phone.text.trim(), code);
  });

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(custAuthControllerProvider);
    final expired = auth is AuthSignedOut && auth.expired;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    size: 48,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chứng chỉ tiền gửi',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _codeStep
                        ? 'Nhập mã OTP vừa gửi tới ${_phone.text.trim()}'
                        : 'Đăng nhập bằng số điện thoại đã đăng ký với ngân hàng',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  if (expired && !_codeStep) ...[
                    const _Notice(
                      text:
                          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
                      tone: Tone.warning,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!_codeStep)
                    TextField(
                      key: const Key('phone'),
                      controller: _phone,
                      enabled: !_busy,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _sendCode(),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9+\s.\-]'),
                        ),
                        LengthLimitingTextInputFormatter(16),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    )
                  else
                    TextField(
                      key: const Key('code'),
                      controller: _code,
                      enabled: !_busy,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _verify(),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      style: const TextStyle(letterSpacing: 8, fontSize: 24),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Mã OTP (6 chữ số)',
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _Notice(text: _error!, tone: Tone.danger),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : (_codeStep ? _verify : _sendCode),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_codeStep ? 'Đăng nhập' : 'Nhận mã OTP'),
                  ),
                  if (_codeStep) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: (_busy || _resendIn > 0) ? null : _sendCode,
                      child: Text(
                        _resendIn > 0
                            ? 'Gửi lại mã sau $_resendIn giây'
                            : 'Gửi lại mã',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _codeStep = false;
                              _code.clear();
                              _error = null;
                            }),
                      child: const Text('Đổi số điện thoại'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Chưa nhận được mã? Số của bạn cần được ngân hàng kích hoạt cho ứng dụng. '
                    'Liên hệ chi nhánh để được hỗ trợ.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Invalid implements Exception {
  const _Invalid(this.message);
  final String message;
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.tone});
  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tones;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.bg(tone),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: TextStyle(color: t.fg(tone))),
      ),
    );
  }
}
