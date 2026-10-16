import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/network/api_exception.dart';
import 'customer_providers.dart';
import 'kh_theme.dart';
import 'kh_widgets.dart';

/// Đổi mật khẩu. [forced] = lần đầu đăng nhập bằng mật khẩu tạm của nhân viên: không có nút quay lại, chỉ thoát bằng
/// cách đổi (hoặc đăng xuất). Chính sách mật khẩu khớp máy chủ: ≥ 10 ký tự, có chữ hoa, chữ thường và chữ số.
class CustomerPasswordScreen extends ConsumerStatefulWidget {
  const CustomerPasswordScreen({super.key, this.forced = false});
  final bool forced;

  @override
  ConsumerState<CustomerPasswordScreen> createState() => _State();
}

class _State extends ConsumerState<CustomerPasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _currentError;
  String? _nextError;
  String? _confirmError;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  static String? ruleError(String p) {
    if (p.length < 10) return 'Mật khẩu tối thiểu 10 ký tự.';
    if (!RegExp('[A-Z]').hasMatch(p)) return 'Cần ít nhất 1 chữ hoa.';
    if (!RegExp('[a-z]').hasMatch(p)) return 'Cần ít nhất 1 chữ thường.';
    if (!RegExp('[0-9]').hasMatch(p)) return 'Cần ít nhất 1 chữ số.';
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _currentError = _current.text.isEmpty ? 'Nhập mật khẩu hiện tại.' : null;
      _nextError =
          ruleError(_next.text) ??
          (_next.text == _current.text
              ? 'Mật khẩu mới phải khác mật khẩu hiện tại.'
              : null);
      _confirmError = _confirm.text != _next.text
          ? 'Mật khẩu nhập lại không khớp.'
          : null;
    });
    if (_currentError != null || _nextError != null || _confirmError != null) {
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(custAuthControllerProvider.notifier)
          .changePassword(_current.text, _next.text);
      if (!mounted) return;
      if (widget.forced) {
        return; // router tự chuyển về Trang chủ khi hết cờ "phải đổi mật khẩu"
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Đã đổi mật khẩu.')));
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        final field = e.fieldErrors['currentPassword'];
        if (field != null) {
          _currentError = field;
        } else if (e.fieldErrors['newPassword'] != null) {
          _nextError = e.fieldErrors['newPassword'];
        } else {
          _error = e.message;
        }
      });
    } on Object {
      if (mounted) setState(() => _error = 'Có lỗi xảy ra. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kh;
    return Scaffold(
      body: Column(
        children: [
          KhTopBar(
            title: widget.forced ? 'Tạo mật khẩu mới' : 'Đổi mật khẩu',
            onBack: widget.forced ? null : () => context.pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.forced) ...[
                    const KhNote(
                      'Bạn đang dùng mật khẩu tạm do ngân hàng cấp. Hãy tạo mật khẩu của riêng bạn để tiếp tục.',
                      icon: LucideIcons.shieldCheck,
                    ),
                    const SizedBox(height: 18),
                  ],
                  KhField(
                    key: const Key('current'),
                    label: widget.forced ? 'Mật khẩu tạm' : 'Mật khẩu hiện tại',
                    controller: _current,
                    icon: LucideIcons.lock,
                    obscure: true,
                    enabled: !_busy,
                    errorText: _currentError,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 18),
                  KhField(
                    key: const Key('new'),
                    label: 'Mật khẩu mới',
                    controller: _next,
                    icon: LucideIcons.keyRound,
                    obscure: true,
                    enabled: !_busy,
                    errorText: _nextError,
                    textInputAction: TextInputAction.next,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 0, 0),
                    child: Text(
                      'Tối thiểu 10 ký tự, gồm chữ hoa, chữ thường và chữ số.',
                      style: KhType.c.copyWith(color: k.ink3),
                    ),
                  ),
                  const SizedBox(height: 18),
                  KhField(
                    key: const Key('confirm'),
                    label: 'Nhập lại mật khẩu mới',
                    controller: _confirm,
                    icon: LucideIcons.keyRound,
                    obscure: true,
                    enabled: !_busy,
                    errorText: _confirmError,
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
                  const SizedBox(height: 24),
                  KhButton(
                    label: 'Lưu mật khẩu',
                    onPressed: _busy ? null : _submit,
                    busy: _busy,
                  ),
                  if (widget.forced) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _busy
                            ? null
                            : () => ref
                                  .read(custAuthControllerProvider.notifier)
                                  .logout(),
                        child: Text(
                          'Đăng xuất',
                          style: TextStyle(
                            color: k.bad,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
