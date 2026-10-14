import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/auth/auth_models.dart';
import '../../../core/auth/providers.dart';
import '../../../core/models/paged.dart';
import '../../../core/money/money_action.dart';
import '../../../core/paging/paged_notifier.dart';
import '../../../core/ui/paged_list.dart';
import '../../../core/ui/snack.dart';
import '../../../core/ui/theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/labels.dart';
import '../../../core/utils/text.dart';
import '../../more/presentation/change_password_screen.dart'
    show passwordProblem;
import '../data/admin_dto.dart';
import 'admin_common.dart';

class UserQuery {
  const UserQuery({this.role = '', this.search = ''});
  final String role;
  final String search;
  UserQuery copyWith({String? role, String? search}) =>
      UserQuery(role: role ?? this.role, search: search ?? this.search);
}

class UserQueryNotifier extends Notifier<UserQuery> {
  @override
  UserQuery build() => const UserQuery();

  // ignore: use_setters_to_change_properties
  void set(UserQuery q) => state = q;
}

final userQueryProvider = NotifierProvider<UserQueryNotifier, UserQuery>(
  UserQueryNotifier.new,
);

class UsersNotifier extends PagedNotifier<AdminUser> {
  @override
  PagedState<AdminUser> build() {
    ref.watch(userQueryProvider);
    return super.build();
  }

  @override
  Future<Paged<AdminUser>> fetch(int page) {
    final q = ref.read(userQueryProvider);
    return ref
        .read(adminRepositoryProvider)
        .users(page: page, search: q.search, role: q.role);
  }
}

final usersProvider = NotifierProvider<UsersNotifier, PagedState<AdminUser>>(
  UsersNotifier.new,
);

/// Chính sách tên đăng nhập của backend.
final _usernameRe = RegExp(r'^[A-Za-z0-9._-]{3,50}$');

/// Quản lý tài khoản nhân viên (chỉ Admin).
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  // Chỉ dựng thân màn (và tải dữ liệu) khi là Admin.
  @override
  Widget build(BuildContext context) =>
      const AdminOnly(title: 'Người dùng', child: _UsersBody());
}

class _UsersBody extends ConsumerStatefulWidget {
  const _UsersBody();

  @override
  ConsumerState<_UsersBody> createState() => _UsersBodyState();
}

class _UsersBodyState extends ConsumerState<_UsersBody> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => ref
          .read(userQueryProvider.notifier)
          .set(ref.read(userQueryProvider).copyWith(search: v.trim())),
    );
  }

  Future<void> _open({AdminUser? user}) async {
    final changed = await showAdminSheet<bool>(
      context,
      UserFormSheet(user: user),
    );
    if (changed ?? false) {
      await ref.read(usersProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersProvider);
    final query = ref.watch(userQueryProvider);
    final notifier = ref.read(usersProvider.notifier);
    final me = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Người dùng'),
        actions: [
          IconBtn(
            icon: LucideIcons.userPlus,
            label: 'Thêm người dùng',
            onPressed: _open,
          ),
        ],
      ),
      body: Column(
        children: [
          SearchField(hint: 'Tên, tên đăng nhập', onChanged: _onSearch),
          FilterChipsRow<String>(
            options: const [
              ('', 'Tất cả'),
              ('Admin', 'Quản trị'),
              ('Operator', 'Nghiệp vụ'),
              ('Viewer', 'Chỉ xem'),
            ],
            value: query.role,
            onChanged: (v) => ref
                .read(userQueryProvider.notifier)
                .set(query.copyWith(role: v)),
          ),
          Expanded(
            child: PagedListView<AdminUser>(
              state: state,
              onRefresh: notifier.refresh,
              onLoadMore: notifier.loadMore,
              emptyTitle: 'Không có người dùng phù hợp',
              emptyMessage: 'Thử đổi bộ lọc hoặc từ khoá tìm kiếm.',
              separatorHeight: 8,
              itemBuilder: (context, u) => ListGroup(
                children: [
                  ListRow(
                    lead: Lead(text: initialsOf(u.fullName)),
                    title: u.fullName,
                    subtitle:
                        '@${u.username} · ${Role.parse(u.role).label}'
                        '${u.id == me.id ? ' · bạn' : ''}',
                    trailing: u.isActive
                        ? null
                        : const StatusChip((
                            label: 'Vô hiệu',
                            tone: Tone.neutral,
                          )),
                    chevron: true,
                    onTap: () => _open(user: u),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tạo mới ([user] = null) hoặc sửa tài khoản. Mọi thao tác ghi cần xác thực sinh trắc.
class UserFormSheet extends ConsumerStatefulWidget {
  const UserFormSheet({super.key, this.user});
  final AdminUser? user;

  @override
  ConsumerState<UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends ConsumerState<UserFormSheet> {
  late final _username = TextEditingController(text: widget.user?.username);
  late final _name = TextEditingController(text: widget.user?.fullName);
  final _password = TextEditingController();
  late String _role = widget.user?.role ?? 'Viewer';
  late bool _active = widget.user?.isActive ?? true;
  Map<String, String> _errors = {};
  bool _busy = false;

  bool get _isNew => widget.user == null;

  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Map<String, String> _validate() {
    final e = <String, String>{};
    if (_isNew && !_usernameRe.hasMatch(_username.text.trim())) {
      e['username'] = '3–50 ký tự: chữ, số, dấu . _ -';
    }
    if (_isNew) {
      final p = passwordProblem(_password.text);
      if (p != null) e['password'] = p;
    }
    final n = _name.text.trim();
    if (n.isEmpty) e['fullName'] = 'Họ và tên không được trống.';
    if (n.length > 200) e['fullName'] = 'Tối đa 200 ký tự.';
    return e;
  }

  Future<void> _save() async {
    if (_busy) return;
    final local = _validate();
    setState(() => _errors = local);
    if (local.isNotEmpty) return;
    setState(() => _busy = true);
    final repo = ref.read(adminRepositoryProvider);
    final ok = await runMoneyAction<bool>(
      context,
      ref,
      reason: _isNew
          ? 'Xác thực để tạo tài khoản'
          : 'Xác thực để cập nhật tài khoản',
      onFieldErrors: (f) => setState(() => _errors = f),
      action: () async {
        if (_isNew) {
          await repo.createUser(
            username: _username.text,
            password: _password.text,
            fullName: _name.text,
            role: _role,
          );
        } else {
          await repo.updateUser(
            id: widget.user!.id,
            fullName: _name.text,
            role: _role,
            isActive: _active,
          );
        }
        return true;
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok ?? false) {
      showSnack(context, _isNew ? 'Đã tạo tài khoản' : 'Đã cập nhật tài khoản');
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _resetPassword() async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _ResetPasswordDialog(user: widget.user!),
    );
    if ((done ?? false) && mounted) {
      showSnack(
        context,
        'Đã đặt lại mật khẩu. Hãy chuyển mật khẩu mới cho nhân viên qua kênh an toàn.',
      );
    }
  }

  Widget _field(
    String key,
    TextEditingController c,
    String label, {
    bool obscure = false,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: c,
      enabled: enabled,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: !obscure,
      decoration: InputDecoration(
        labelText: label,
        errorText: _errors[key],
        errorMaxLines: 3,
      ),
      onChanged: (_) {
        if (_errors.containsKey(key)) {
          setState(() => _errors = {..._errors}..remove(key));
        }
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final isSelf = widget.user?.id == me.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isNew ? 'Thêm người dùng' : 'Sửa người dùng',
          style: context.text.titleLarge,
        ),
        const SizedBox(height: 16),
        _field('username', _username, 'Tên đăng nhập', enabled: _isNew),
        _field('fullName', _name, 'Họ và tên'),
        if (_isNew)
          _field('password', _password, 'Mật khẩu ban đầu', obscure: true),
        Text('Vai trò', style: context.text.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final r in Role.values)
              ButtonSegment(value: r.code, label: Text(r.label)),
          ],
          selected: {_role},
          onSelectionChanged: isSelf
              ? null
              : (s) => setState(() => _role = s.first),
        ),
        if (!_isNew) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Đang hoạt động'),
            subtitle: const Text('Tắt sẽ thu hồi mọi phiên đăng nhập của họ.'),
            value: _active,
            onChanged: isSelf ? null : (v) => setState(() => _active = v),
          ),
          if (isSelf)
            Text(
              'Bạn không thể đổi vai trò hoặc vô hiệu hoá chính mình.',
              style: context.text.bodySmall?.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          if (widget.user!.lastLoginAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Đăng nhập gần nhất: ${formatDateTime(widget.user!.lastLoginAt)}',
                style: context.text.bodySmall?.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Đang lưu…' : 'Lưu'),
        ),
        if (!_isNew && !isSelf) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _resetPassword,
            icon: const Icon(LucideIcons.keyRound, size: 18),
            label: const Text('Đặt lại mật khẩu'),
          ),
        ],
      ],
    );
  }
}

class _ResetPasswordDialog extends ConsumerStatefulWidget {
  const _ResetPasswordDialog({required this.user});
  final AdminUser user;

  @override
  ConsumerState<_ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<_ResetPasswordDialog> {
  final _pw = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final p = passwordProblem(_pw.text);
    if (p != null) {
      setState(() => _error = p);
      return;
    }
    setState(() => _busy = true);
    final ok = await runMoneyAction<bool>(
      context,
      ref,
      reason: 'Xác thực để đặt lại mật khẩu',
      onFieldErrors: (f) => setState(() => _error = f.values.first),
      action: () async {
        await ref
            .read(adminRepositoryProvider)
            .resetPassword(widget.user.id, _pw.text);
        return true;
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok ?? false) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Đặt lại mật khẩu cho @${widget.user.username}'),
    content: TextField(
      controller: _pw,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: 'Mật khẩu mới',
        errorText: _error,
        errorMaxLines: 3,
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        child: const Text('Huỷ'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        onPressed: _busy ? null : _submit,
        child: const Text('Đặt lại'),
      ),
    ],
  );
}
