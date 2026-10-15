import 'dart:io' show Platform;

class AppConstants {
  // Đổi thành địa chỉ backend thật khi deploy.
  // - Android emulator gọi máy host qua 10.0.2.2
  // - iOS simulator gọi thẳng localhost của máy host
  // - Thiết bị thật trong cùng mạng: thay bằng IP LAN của máy chạy backend
  static final String baseUrl = Platform.isAndroid
      ? 'http://10.0.2.2:5000/api'
      : 'http://localhost:5000/api';

  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
}
