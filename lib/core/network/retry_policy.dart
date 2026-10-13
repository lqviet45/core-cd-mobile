/// Riverpod 3 mặc định tự thử lại provider lỗi tới 10 lần với độ trễ tăng dần: màn hình kẹt ở trạng thái đang tải cả
/// phút và máy chủ bị gọi dồn dập khi mất mạng/403/404. App này không tự thử lại: lỗi hiện ngay kèm nút "Thử lại"
/// và kéo để làm mới. (Thao tác ghi tiền càng không được lặp ngầm.)
Duration? noAutoRetry(int retryCount, Object error) => null;
