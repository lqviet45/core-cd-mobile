/// Trang dữ liệu chuẩn của backend (`PaginatedList`).
class Paged<T> {
  const Paged({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory Paged.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) item,
  ) => Paged(
    items: (j['items'] as List<dynamic>)
        .map((e) => item(e as Map<String, dynamic>))
        .toList(),
    pageNumber: j['pageNumber'] as int,
    pageSize: j['pageSize'] as int,
    totalCount: j['totalCount'] as int,
    totalPages: j['totalPages'] as int,
  );

  final List<T> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  bool get hasNextPage => pageNumber < totalPages;
}
