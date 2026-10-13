import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paged.dart';

/// Trạng thái danh sách phân trang cuộn vô hạn.
class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.page = 0,
    this.total = 0,
    this.hasMore = false,
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.loadMoreError,
  });

  final List<T> items;
  final int page;
  final int total;
  final bool hasMore;

  /// Đang tải trang đầu (hiện khung chờ).
  final bool loading;

  /// Đang tải thêm trang tiếp theo (hiện vòng quay cuối danh sách).
  final bool loadingMore;

  /// Lỗi khi tải trang đầu.
  final Object? error;

  /// Lỗi khi tải thêm: giữ nguyên danh sách đã có, cho phép thử lại.
  final Object? loadMoreError;

  bool get isEmpty => items.isEmpty && !loading && error == null;
}

/// Nền tảng cho danh sách phân trang. Lớp con khai báo `fetch(page)` và (nếu có bộ lọc) `ref.watch` provider
/// bộ lọc trong `build()` – đổi bộ lọc sẽ dựng lại notifier và tải lại từ trang 1.
abstract class PagedNotifier<T> extends Notifier<PagedState<T>> {
  int _generation = 0;

  Future<Paged<T>> fetch(int page);

  @override
  PagedState<T> build() {
    // Dựng lại (đổi bộ lọc) → bỏ kết quả của lần tải cũ.
    final gen = ++_generation;
    unawaited(Future.microtask(() => _loadFirst(gen)));
    return const PagedState(loading: true);
  }

  Future<void> refresh() => _loadFirst(++_generation);

  Future<void> _loadFirst(int gen) async {
    if (gen != _generation) return;
    if (!state.loading) {
      state = PagedState(
        items: state.items,
        page: state.page,
        total: state.total,
        hasMore: state.hasMore,
        loading: state.items.isEmpty,
      );
    }
    try {
      final p = await fetch(1);
      if (gen != _generation) return;
      state = PagedState(
        items: p.items,
        page: 1,
        total: p.totalCount,
        hasMore: p.hasNextPage,
      );
    } on Object catch (e) {
      if (gen != _generation) return;
      state = PagedState(
        items: state.items,
        error: state.items.isEmpty ? e : null,
        total: state.total,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore || state.loading) return;
    final gen = _generation;
    state = PagedState(
      items: state.items,
      page: state.page,
      total: state.total,
      hasMore: true,
      loadingMore: true,
    );
    try {
      final p = await fetch(state.page + 1);
      if (gen != _generation) return;
      state = PagedState(
        items: [...state.items, ...p.items],
        page: p.pageNumber,
        total: p.totalCount,
        hasMore: p.hasNextPage,
      );
    } on Object catch (e) {
      if (gen != _generation) return;
      state = PagedState(
        items: state.items,
        page: state.page,
        total: state.total,
        hasMore: true,
        loadMoreError: e,
      );
    }
  }
}
