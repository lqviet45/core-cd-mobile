import 'package:flutter/material.dart';

import '../paging/paged_notifier.dart';
import 'theme.dart';
import 'widgets.dart';

/// Hiển thị một [PagedState]: khung chờ / lỗi / rỗng / danh sách cuộn vô hạn có kéo-để-làm-mới.
class PagedListView<T> extends StatefulWidget {
  const PagedListView({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.itemBuilder,
    this.emptyTitle = 'Không có dữ liệu',
    this.emptyMessage,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(Tokens.gap, 4, Tokens.gap, 24),
    this.separatorHeight = 12,
  });

  final PagedState<T> state;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyTitle;
  final String? emptyMessage;
  final Widget? header;
  final EdgeInsetsGeometry padding;
  final double separatorHeight;

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (_controller.position.extentAfter < 400) widget.onLoadMore();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    if (s.loading) return const ListSkeleton();
    if (s.error != null) {
      return ErrorState(error: s.error!, onRetry: widget.onRefresh);
    }

    final headerCount = widget.header == null ? 0 : 1;
    final footer = (s.loadingMore || s.loadMoreError != null) ? 1 : 0;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: s.isEmpty
          ? LayoutBuilder(
              builder: (context, c) => ListView(
                controller: _controller,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (widget.header != null) widget.header!,
                  SizedBox(
                    height: c.maxHeight * .6,
                    child: EmptyState(
                      title: widget.emptyTitle,
                      message: widget.emptyMessage,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              controller: _controller,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: widget.padding,
              itemCount: headerCount + s.items.length + footer,
              separatorBuilder: (_, __) =>
                  SizedBox(height: widget.separatorHeight),
              itemBuilder: (context, i) {
                if (i < headerCount) return widget.header!;
                final idx = i - headerCount;
                if (idx < s.items.length) {
                  return widget.itemBuilder(context, s.items[idx]);
                }
                if (s.loadMoreError != null) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: widget.onLoadMore,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Không tải thêm được – thử lại'),
                    ),
                  );
                }
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
