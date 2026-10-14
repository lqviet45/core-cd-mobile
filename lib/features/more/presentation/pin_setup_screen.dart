import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/pin_providers.dart';
import '../../../core/auth/pin_service.dart';
import '../../../core/auth/providers.dart';
import '../../../core/ui/pin_pad.dart';
import '../../../core/ui/snack.dart';
import '../../../core/ui/theme.dart';

enum _Step { current, create, confirm }

/// Đặt, đổi hoặc tắt mã PIN 6 số của app.
/// - Chưa có PIN: tạo → nhập lại.
/// - Đã có PIN: nhập PIN hiện tại trước (sai quá số lần → xoá PIN và đăng xuất), rồi tạo mới → nhập lại, hoặc tắt ([remove]).
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key, this.remove = false});
  final bool remove;

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  _Step? _step; // null = đang đọc trạng thái
  String? _first;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final has = await ref.read(pinEnabledProvider.future);
    if (mounted) setState(() => _step = has ? _Step.current : _Step.create);
  }

  String get _userId {
    final a = ref.read(authControllerProvider);
    return a is AuthSignedIn ? a.user.id : '';
  }

  Future<void> _onPin(String pin) async {
    final svc = ref.read(pinServiceProvider);
    switch (_step!) {
      case _Step.current:
        final r = await svc.verify(_userId, pin);
        if (!mounted) return;
        switch (r) {
          case PinOk():
            if (widget.remove) {
              await svc.clear(_userId);
              await ref.read(pinEnabledProvider.notifier).refresh();
              if (!mounted) return;
              showSnack(context, 'Đã tắt mã PIN');
              context.pop();
            } else {
              setState(() {
                _step = _Step.create;
                _error = null;
              });
            }
          case PinWrong(:final attemptsLeft):
            setState(() => _error = 'Sai mã PIN. Còn $attemptsLeft lần thử.');
          case PinLockedOut():
            // PIN đã bị xoá; đăng xuất để buộc nhập lại mật khẩu.
            await ref.read(authControllerProvider.notifier).logout();
        }
      case _Step.create:
        final problem = pinProblem(pin);
        setState(() {
          _error = problem;
          if (problem == null) {
            _first = pin;
            _step = _Step.confirm;
          }
        });
      case _Step.confirm:
        if (pin != _first) {
          setState(() {
            _error = 'Hai lần nhập không khớp. Nhập lại mã PIN mới.';
            _first = null;
            _step = _Step.create;
          });
          return;
        }
        await svc.set(_userId, pin);
        await ref.read(pinEnabledProvider.notifier).refresh();
        if (!mounted) return;
        showSnack(context, 'Đã lưu mã PIN');
        context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final title = widget.remove ? 'Tắt mã PIN' : 'Mã PIN';
    final (heading, hint) = switch (step) {
      null => ('', ''),
      _Step.current => (
        'Nhập mã PIN hiện tại',
        widget.remove
            ? 'Xác nhận để tắt mã PIN. Bạn vẫn có thể mở khoá bằng vân tay.'
            : 'Xác nhận trước khi đổi sang mã mới.',
      ),
      _Step.create => (
        'Tạo mã PIN mới',
        'Gồm $pinLength chữ số, không phải dãy liên tiếp hay số lặp.',
      ),
      _Step.confirm => ('Nhập lại mã PIN', 'Nhập lại để xác nhận.'),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: step == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(heading, style: context.text.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 28),
                    PinEntry(
                      key: ValueKey(step),
                      onCompleted: _onPin,
                      error: _error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Mã PIN chỉ dùng để mở app trên máy này. Thao tác tiền vẫn cần vân tay hoặc khoá màn hình.',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
