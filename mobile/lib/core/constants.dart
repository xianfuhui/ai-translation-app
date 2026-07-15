class AppConstants {
  // Đổi thành địa chỉ backend thật khi deploy.
  // - Android emulator gọi máy host qua 10.0.2.2
  // - iOS simulator / thiết bị thật trong cùng mạng dùng IP LAN của máy chạy backend
  static const String baseUrl = 'http://10.0.2.2:5000/api';

  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
}
