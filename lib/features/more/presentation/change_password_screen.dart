import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/providers.dart';
import '../../../core/network/api_call.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/ui/snack.dart';
import '../../../core/ui/widgets.dart';

/// Chính sách mật khẩu (khớp backend): tối thiểu 10 ký tự, có chữ hoa, chữ thường và chữ số.
String? passwordProblem(String p) {
  if (p.length < 10) return 'Tối thiểu 10 ký tự.';
  if (!RegExp('[A-Z]').hasMatch(p)) return 'Cần ít nhất một chữ hoa.';
  if (!RegExp('[a-z]').hasMatch(p)) return 'Cần ít nhất một chữ thường.';
  if (!RegExp(r'\d').hasMatch(p)) return 'Cần ít nhất một chữ số.';
  return null;
}

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  Map<String, String> _errors = {};
  bool _busy = false;
  bool _show = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final e = <String, String>{};
    if (_current.text.isEmpty) e['currentPassword'] = 'Nhập mật khẩu hiện tại.';
    final problem = passwordProblem(_next.text);
    if (problem != null) e['newPassword'] = problem;
    if (_confirm.text != _next.text) {
      e['confirm'] = 'Mật khẩu nhập lại không khớp.';
    }
    setState(() => _errors = e);
    if (e.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      await apiCall(
        () => ref
            .read(dioProvider)
            .post<void>(
              '/api/auth/change-password',
              data: {
                'currentPassword': _current.text,
                'newPassword': _next.text,
              },
            ),
      );
      if (!mounted) return;
      showSnack(
        context,
        'Đã đổi mật khẩu. Các thiết bị khác phải đăng nhập lại.',
      );
      context.pop();
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errors = err.fieldErrors.isNotEmpty
            ? err.fieldErrors
            : {'currentPassword': err.message};
      });
    }
  }

  Widget _field(String key, TextEditingController c, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: c,
      obscureText: !_show,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        errorText: _errors[key],
        errorMaxLines: 3,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đổi mật khẩu')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const NoteCard(
          kind: CardKind.primaryContainer,
          text: Text(
            'Mật khẩu tối thiểu 10 ký tự, gồm chữ hoa, chữ thường và chữ số.',
          ),
        ),
        const SizedBox(height: 16),
        _field('currentPassword', _current, 'Mật khẩu hiện tại'),
        _field('newPassword', _next, 'Mật khẩu mới'),
        _field('confirm', _confirm, 'Nhập lại mật khẩu mới'),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _show,
          onChanged: (v) => setState(() => _show = v ?? false),
          title: const Text('Hiện mật khẩu'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    ),
    bottomNavigationBar: BottomBar(
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Đang lưu…' : 'Lưu mật khẩu mới'),
        ),
      ),
    ),
  );
}
