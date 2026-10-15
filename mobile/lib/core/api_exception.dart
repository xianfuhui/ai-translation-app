class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// The backend could not be reached (no internet, server down, timeout) or the
/// call is not allowed in guest mode. Callers treat this as "work offline".
class NetworkException extends ApiException {
  /// True when the call was blocked because the user is a guest (not because
  /// the network is down).
  final bool guest;

  NetworkException([
    String message =
        'Không kết nối được máy chủ. Bạn có thể tiếp tục dùng các tính năng ngoại tuyến.',
    this.guest = false,
  ]) : super(message);
}
