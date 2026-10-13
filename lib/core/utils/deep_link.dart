/// Đường dẫn web của backend (trong thông báo/push) → màn hình mobile tương ứng; `null` = không có trang đích.
String? routeForLink(String? link) {
  if (link == null) return null;
  final lot = RegExp(r'^/lots/([0-9a-fA-F-]{36})$').firstMatch(link);
  if (lot != null) return '/more/lots/${lot.group(1)}';
  final trx = RegExp(r'^/transactions/([0-9a-fA-F-]{36})$').firstMatch(link);
  if (trx != null) return '/transactions/${trx.group(1)}';
  if (link == '/settlement') return '/more/maturities';
  if (link == '/transactions') return '/transactions';
  return null;
}

/// Điều hướng khi chạm vào một push: dùng `data.link`, nếu thiếu thì suy từ `data.type`.
String? routeForPush(Map<String, String> data) {
  final byLink = routeForLink(data['link']);
  if (byLink != null) return byLink;
  return switch (data['type']) {
    'NearMaturity' => '/more/maturities',
    'TransactionFailed' => '/transactions',
    'LotNearlySoldOut' => '/more/lots',
    _ => '/notifications',
  };
}
