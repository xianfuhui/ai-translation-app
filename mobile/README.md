# Mobile App (Flutter) - Dịch ngôn ngữ & Học từ vựng

Khung dự án Flutter kết nối với `backend/` (Node.js API) đã xây dựng trước đó. Đã có đủ luồng **đăng nhập/đăng ký**, gọi API cho **AI Assistant, Từ vựng, Lịch sử, Ngôn ngữ**, và khung màn hình cho **Dịch/STT/TTS/Flashcard**.

## 1. Yêu cầu

- Flutter SDK >= 3.3 (`flutter --version` để kiểm tra)
- Backend (`backend/`) đang chạy — xem README trong đó

## 2. Cài đặt & chạy

```bash
cd mobile_app
flutter pub get
flutter run
```

### Cấu hình địa chỉ backend

Sửa `lib/core/constants.dart`:
```dart
static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android emulator
// Thiết bị thật / iOS simulator: dùng IP LAN của máy chạy backend, vd:
// static const String baseUrl = 'http://192.168.1.10:5000/api';
```

## 3. Kiến trúc

```
lib/
├── main.dart                     # Entry point, theme, Provider
├── core/
│   ├── constants.dart            # baseUrl, storage keys
│   ├── api_client.dart           # HTTP client dùng chung + JWT
│   └── api_exception.dart
├── models/                       # User, Language, Vocabulary, History, AIConversation
├── services/                     # Gọi API theo từng module (auth, ai, vocabulary, history, language)
├── providers/
│   └── auth_provider.dart        # State đăng nhập toàn app (Provider/ChangeNotifier)
└── screens/
    ├── splash_screen.dart
    ├── home_screen.dart          # Bottom navigation 5 tab
    ├── auth/                     # Đăng nhập, Đăng ký
    ├── translate/                # Dịch ngôn ngữ (chọn ngôn ngữ, STT, TTS)
    ├── ai/                       # AI Assistant (chat + tóm tắt)
    ├── vocabulary/                # Từ vựng yêu thích, kho hệ thống, Flashcard
    ├── history/                  # Lịch sử dịch thuật
    └── profile/                  # Đổi mật khẩu, đăng xuất
```

## 4. Trạng thái từng module (theo bảng chức năng)

| Module | Trạng thái trong scaffold này |
|---|---|
| Đăng ký / Đăng nhập / Đăng xuất / Đổi mật khẩu | ✅ Hoạt động đầy đủ, gọi thẳng API backend |
| Chọn ngôn ngữ | ✅ Lấy danh sách từ API, hiển thị dropdown |
| Speech-to-Text (Vosk) | 🚧 Có nút mic + điểm nối `_toggleListening()`, cần tích hợp gói `vosk_flutter` thật (xem mục 5) |
| Text-to-Speech | ✅ Đã tích hợp `flutter_tts`, hoạt động ngay (dùng engine TTS hệ thống) |
| Dịch văn bản | 🚧 Có UI đầy đủ, hàm `_translate()` là điểm nối để cắm engine dịch offline thật |
| AI Assistant (chat + tóm tắt) | ✅ Hoạt động đầy đủ, gọi Gemini qua backend |
| Lưu từ vựng (chạm từ trong bản dịch / tự nhập) | ✅ Hoạt động đầy đủ |
| Kho từ vựng hệ thống | ✅ Xem & lưu về từ vựng cá nhân |
| Flashcard (kèm audio phát âm) | ✅ Lật thẻ xem nghĩa, phát âm bằng TTS; audio từ điển online lấy tự động khi lưu từ (xử lý ở backend) |
| Lịch sử dịch thuật | ✅ Xem, vuốt để xóa |

## 5. Tích hợp Vosk (Speech-to-Text offline) — bước tiếp theo

Gói `vosk_flutter` **chưa được thêm sẵn** vào `pubspec.yaml` vì bản hiện tại của nó yêu cầu `http ^0.13.x`, xung đột với `http ^1.x` mà project đang dùng để gọi backend. Khi bạn sẵn sàng tích hợp:

1. Thử thêm gói:
   ```bash
   flutter pub add vosk_flutter
   ```
   - Nếu báo xung đột version `http` như trên, kiểm tra xem `vosk_flutter` đã có bản mới hỗ trợ `http ^1.x` chưa (xem https://pub.dev/packages/vosk_flutter/versions). Gói STT offline thường cập nhật chậm hơn.
   - Nếu chưa có, cân nhắc 2 hướng: (a) hạ `http` xuống `^0.13.6` (API gần tương tự `http ^1.x`, chỉ cần sửa vài chỗ nếu có lỗi), hoặc (b) dùng gói STT offline khác đang được bảo trì tốt hơn (tìm "speech to text offline" trên pub.dev).
2. Tải model Vosk tương ứng ngôn ngữ (vd `vosk-model-small-en-us-0.15`) — tên model admin cấu hình sẵn trong trường `voskModelName` của mỗi `Language` (xem Web Admin → Ngôn ngữ).
3. Đóng gói model vào `assets/models/` hoặc tải về máy lần đầu chạy app rồi lưu vào thư mục local.
4. Trong `_toggleListening()` (file `translate_screen.dart`), khởi tạo plugin STT, tạo `Recognizer` với model đã tải, lắng nghe audio stream và đổ text nhận dạng được vào `_inputController`.

## 6. Việc tiếp theo có thể làm

- Cắm engine dịch offline thật (vd TensorFlow Lite model theo `translationModel` của từng ngôn ngữ) vào `_translate()`.
- Hoàn thiện tích hợp Vosk như hướng dẫn ở mục 5.
- Thêm cache offline (Hive/SQLite) để xem lại lịch sử/từ vựng khi mất mạng.
- Thêm animation chuyển màn hình, dark mode.
