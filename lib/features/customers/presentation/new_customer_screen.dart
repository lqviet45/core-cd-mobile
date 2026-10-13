import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/api_providers.dart';
import '../../../core/money/money_gate.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/connectivity.dart';
import '../../../core/ui/snack.dart';
import '../../../core/ui/widgets.dart';
import 'customer_screens.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// M12 – Thêm khách hàng. Không phải thao tác tiền nên không cần sinh trắc, nhưng cần quyền Operator và mạng.
class NewCustomerScreen extends ConsumerStatefulWidget {
  const NewCustomerScreen({super.key});

  @override
  ConsumerState<NewCustomerScreen> createState() => _NewCustomerScreenState();
}

class _NewCustomerScreenState extends ConsumerState<NewCustomerScreen> {
  String _type = 'Individual';
  final _cif = TextEditingController();
  final _name = TextEditingController();
  final _identity = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _brn = TextEditingController();
  final _rep = TextEditingController();
  final _repTitle = TextEditingController();
  Map<String, String> _errors = {};
  bool _busy = false;

  bool get _business => _type == 'Business';

  @override
  void dispose() {
    for (final c in [
      _cif,
      _name,
      _identity,
      _phone,
      _email,
      _address,
      _brn,
      _rep,
      _repTitle,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> _validate() {
    final e = <String, String>{};
    if (_cif.text.trim().isEmpty) e['cif'] = 'CIF không được trống.';
    if (_name.text.trim().isEmpty) {
      e['fullName'] = _business
          ? 'Tên công ty không được trống.'
          : 'Họ và tên không được trống.';
    }
    if (_identity.text.trim().isEmpty) {
      e['identityNumber'] = _business
          ? 'Mã số thuế không được trống.'
          : 'Số CCCD/CMND không được trống.';
    }
    if (_phone.text.trim().isEmpty) {
      e['phone'] = 'Số điện thoại không được trống.';
    }
    if (!_emailRe.hasMatch(_email.text.trim())) {
      e['email'] = 'Email không hợp lệ.';
    }
    return e;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final local = _validate();
    setState(() => _errors = local);
    if (local.isNotEmpty) return;
    if (!ref.read(canWriteProvider)) {
      showSnack(
        context,
        'Bạn không có quyền thực hiện thao tác này.',
        error: true,
      );
      return;
    }
    if (!(ref.read(isOnlineProvider).value ?? true)) {
      showSnack(
        context,
        'Đang offline. Vui lòng thử lại khi có mạng.',
        error: true,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(customerRepositoryProvider)
          .create(
            customerType: _type,
            cif: _cif.text,
            fullName: _name.text,
            identityNumber: _identity.text,
            email: _email.text,
            phone: _phone.text,
            address: _address.text,
            businessRegistrationNumber: _business ? _brn.text : null,
            representativeName: _business ? _rep.text : null,
            representativeTitle: _business ? _repTitle.text : null,
          );
      if (!mounted) return;
      ref.invalidate(customersProvider);
      showSnack(context, 'Đã tạo khách hàng');
      context.go('/customers/$id');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errors = e.fieldErrors;
      });
      if (e.fieldErrors.isEmpty) showSnack(context, e.message, error: true);
    }
  }

  Widget _field(
    String key,
    TextEditingController c,
    String label, {
    TextInputType? type,
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: optional ? '$label (không bắt buộc)' : label,
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconBtn(
        icon: LucideIcons.x,
        label: 'Đóng',
        onPressed: () => context.pop(),
      ),
      title: const Text('Thêm khách hàng'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Individual', label: Text('Cá nhân')),
            ButtonSegment(value: 'Business', label: Text('Doanh nghiệp')),
          ],
          selected: {_type},
          onSelectionChanged: (v) => setState(() => _type = v.first),
        ),
        const SizedBox(height: 20),
        _field('cif', _cif, 'Mã CIF'),
        _field('fullName', _name, _business ? 'Tên công ty' : 'Họ và tên'),
        _field(
          'identityNumber',
          _identity,
          _business ? 'Mã số thuế' : 'Số CCCD / CMND',
          type: TextInputType.number,
        ),
        _field('phone', _phone, 'Số điện thoại', type: TextInputType.phone),
        _field('email', _email, 'Email', type: TextInputType.emailAddress),
        _field('address', _address, 'Địa chỉ', optional: true),
        if (_business) ...[
          _field('businessRegistrationNumber', _brn, 'Số ĐKKD', optional: true),
          _field('representativeName', _rep, 'Người đại diện', optional: true),
          _field('representativeTitle', _repTitle, 'Chức danh', optional: true),
        ],
      ],
    ),
    bottomNavigationBar: BottomBar(
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => context.pop(),
              child: const Text('Huỷ'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Đang tạo…' : 'Tạo khách hàng'),
            ),
          ),
        ],
      ),
    ),
  );
}
