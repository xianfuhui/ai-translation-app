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
| Dịch văn bản | ✅ Dịch offline thật bằng Google ML Kit Translation (`google_mlkit_translation`), tự tải model theo cấu hình Admin (xem mục 6) |
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
2. Lấy model Vosk cho ngôn ngữ cần dùng — **ưu tiên tải trực tiếp từ backend** nếu Admin đã upload file (xem mục 7):
   ```dart
   final voskModel = await ModelService().getActiveVoskModel(languageCode);
   final downloadUrl = ModelService().getDownloadUrl(voskModel!); // link file .zip thật trên backend, hoặc link ngoài nếu Admin chưa upload
   ```
3. Tải file `.zip` về máy (dùng `http`/`dio`), giải nén vào thư mục local (vd `path_provider` + `archive` package để giải nén).
4. Trong `_startLiveTranslate()` (file `translate_screen.dart`), khởi tạo plugin STT với model đã giải nén, lắng nghe audio stream, và gọi `_onSpeechRecognized(text)` mỗi khi nhận diện xong 1 câu — chỗ này đã viết sẵn, chỉ cần nối vào.

## 6. Dịch offline bằng ML Kit — đã tích hợp sẵn

`lib/services/translation_service.dart` dùng gói `google_mlkit_translation` để dịch trực tiếp trên máy, không cần gọi API dịch bên ngoài.

**Cách hoạt động:**
1. Khi bấm Dịch, app gọi `ModelService.getActiveMlkitModel(languageCode)` để hỏi backend xem Admin đã cấu hình model ML Kit nào cho ngôn ngữ này chưa (Web Admin → **Model (Vosk/ML Kit)** → tab ML Kit).
2. Nếu có, dùng `identifier` Admin đã đặt (chính là mã ngôn ngữ ML Kit, vd `en`, `vi`, `ja`); nếu Admin chưa cấu hình, dùng tạm mã ngôn ngữ mặc định (`Language.code`).
3. Nếu model dịch cho ngôn ngữ đó **chưa có sẵn trên máy**, app tự động tải về (chỉ 1 lần, ~30MB/ngôn ngữ) — có banner "Đang tải model dịch..." hiển thị trong lúc chờ.
4. Từ lần dịch sau, model đã có sẵn nên dịch ngay lập tức, hoàn toàn offline.

**Lưu ý:** ML Kit không hỗ trợ mọi ngôn ngữ (danh sách đầy đủ: xem `TranslateLanguage` enum trong gói `google_mlkit_translation`). Nếu Admin đặt 1 ngôn ngữ không được ML Kit hỗ trợ, app sẽ báo lỗi rõ ràng thay vì dịch sai.

## 7. Kho Model (Vosk + ML Kit) do Admin quản lý

Admin quản lý toàn bộ danh sách model qua Web Admin → **Model (Vosk/ML Kit)** — thêm/sửa/xóa/bật-tắt từng model, không cần sửa code. Mobile app tự động lấy danh sách này qua API `/api/models`:

| Trường | Ý nghĩa |
|---|---|
| `type` | `vosk` (Speech-to-Text) hoặc `mlkit` (Dịch) |
| `languageCode` | Mã ngôn ngữ áp dụng, vd `en`, `vi`, `ja` |
| `identifier` | Với Vosk: tên model (vd `vosk-model-small-en-us-0.15`). Với ML Kit: mã ngôn ngữ ML Kit dùng để dịch (vd `en`) |
| `fileUrl` | Đường dẫn file model Admin **đã upload trực tiếp** lên backend (nếu có) — ưu tiên dùng cái này |
| `downloadUrl`, `sizeMB` | Link tải ngoài + kích thước — dùng khi Admin chưa upload file thật |
| `isActive` | Model đang bật/tắt — mobile chỉ dùng model đang bật |

`lib/services/model_service.dart` gọi API này; hàm `getDownloadUrl(model)` tự động trả về **link file thật trên backend** nếu Admin đã upload, hoặc `downloadUrl` ngoài nếu chưa. `translate_screen.dart` dùng service này để biết `identifier` ML Kit nào cần dùng cho từng ngôn ngữ (xem mục 6).

> **Lưu ý về ML Kit:** file Admin upload cho loại `mlkit` chỉ để lưu trữ/tham khảo — bản thân tính năng dịch dùng model chính chủ Google (tự tải theo mã ngôn ngữ trong `identifier`), **không** dùng file upload này.

## 8. Việc tiếp theo có thể làm

- Hoàn thiện tích hợp Vosk như hướng dẫn ở mục 5, dùng `ModelService.getActiveVoskModel()` để lấy `identifier`/`downloadUrl` Admin đã cấu hình.
- Thêm màn hình trong app cho người dùng tự quản lý model đã tải (xem dung lượng, xóa model không dùng) bằng `TranslationService.deleteModel()`.
- Thêm cache offline (Hive/SQLite) để xem lại lịch sử/từ vựng khi mất mạng.
- Thêm animation chuyển màn hình, dark mode.
