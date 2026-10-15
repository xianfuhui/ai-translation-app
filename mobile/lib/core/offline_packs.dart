import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Người dùng bấm "Hủy" khi đang tải model.
class DownloadCancelled implements Exception {
  const DownloadCancelled();

  @override
  String toString() => 'Đã hủy tải model';
}

/// Không có mạng (hoặc không kết nối được nơi chứa model) nên không tải được.
class NoInternetException implements Exception {
  final String message;
  const NoInternetException([
    this.message = 'Không có mạng để tải model. Hãy kết nối mạng rồi thử lại.',
  ]);

  @override
  String toString() => message;
}

/// Công tắc "Hủy" dùng chung cho mọi lượt tải model (thay cho giới hạn thời gian).
class CancelToken {
  bool _cancelled = false;
  final _completer = Completer<void>();

  bool get isCancelled => _cancelled;
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _completer.complete();
  }

  void throwIfCancelled() {
    if (_cancelled) throw const DownloadCancelled();
  }
}

class OfflinePacks {
  OfflinePacks._();

  /// Tăng mỗi khi có gói được tải xong / xóa — để màn Cá nhân tự cập nhật
  /// danh sách "đã tải".
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static void notifyChanged() => changes.value++;

  /// Kiểm tra nhanh thiết bị có Internet không (dùng cho ML Kit, vì ML Kit
  /// tự tải model và không báo lỗi mạng rõ ràng).
  static Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
