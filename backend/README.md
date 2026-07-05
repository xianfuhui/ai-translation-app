# Backend API - Ứng dụng Dịch ngôn ngữ & Học từ vựng

Backend dùng chung cho **Mobile App (Flutter)** và **Web Admin (NodeJS)**.

## 1. Kiến trúc

```
backend/
├── server.js                # Entry point
├── package.json
├── .env.example              # Copy thành .env và điền giá trị thật
└── src/
    ├── config/db.js          # Kết nối MongoDB
    ├── models/                # User, Language, Vocabulary, SystemVocabulary,
    │                          # TranslationHistory, AIConversation
    ├── middleware/            # auth (JWT + phân quyền), errorHandler
    ├── controllers/           # Logic xử lý từng module
    └── routes/                # Định nghĩa endpoint
```

## 2. Cài đặt & chạy

```bash
cd backend
cp .env.example .env     # rồi điền MONGO_URI, JWT_SECRET, GEMINI_API_KEY...
npm install
npm run dev               # hoặc: npm start
```

Yêu cầu: Node.js >= 18, MongoDB (local hoặc Atlas).

## 3. Xác thực

Mọi request cần đăng nhập gửi header:
```
Authorization: Bearer <token>
```
Token lấy được từ response của `/api/auth/login` hoặc `/api/auth/register`.

Vai trò (`role`): `user` (Mobile) hoặc `admin` (Web). Một số route chỉ admin mới gọi được (trả lỗi 403 nếu không đúng quyền).

## 4. Danh sách API theo module (bám sát bảng chức năng)

### Quản lý tài khoản
| Method | Endpoint | Ai dùng | Mô tả |
|---|---|---|---|
| POST | /api/auth/register | Mobile | Đăng ký tài khoản |
| POST | /api/auth/login | Mobile + Admin | Đăng nhập |
| POST | /api/auth/logout | Mobile + Admin | Đăng xuất |
| PUT  | /api/auth/change-password | Mobile + Admin | Đổi mật khẩu |
| GET  | /api/auth/me | Mobile + Admin | Thông tin tài khoản hiện tại |
| GET  | /api/users | Admin | Danh sách người dùng |
| GET/POST/PUT/DELETE | /api/users/:id | Admin | Quản lý tài khoản người dùng |

### Dịch ngôn ngữ (offline trên Mobile — backend chỉ cấp danh mục ngôn ngữ)
| Method | Endpoint | Ai dùng | Mô tả |
|---|---|---|---|
| GET | /api/languages | Mobile | Danh sách ngôn ngữ hỗ trợ để chọn dịch |

> Chọn ngôn ngữ, Speech-to-Text (Vosk), Text-to-Speech (ML Kit) chạy **offline trên thiết bị**, backend chỉ cung cấp cấu hình model (`voskModelName`, `translationModel`) qua API ngôn ngữ ở trên.

### AI Assistant (Gemini)
| Method | Endpoint | Ai dùng | Mô tả |
|---|---|---|---|
| POST | /api/ai/chat | Mobile | Gửi tin nhắn hội thoại với AI |
| POST | /api/ai/summarize/:conversationId | Mobile | Tóm tắt hội thoại |
| GET  | /api/ai/conversations | Mobile | Danh sách hội thoại đã lưu |
| GET  | /api/ai/conversations/:id | Mobile | Chi tiết 1 hội thoại |

### Quản lý từ vựng
| Method | Endpoint | Ai dùng | Mô tả |
|---|---|---|---|
| POST | /api/vocabulary | Mobile | Lưu từ vựng yêu thích |
| GET  | /api/vocabulary | Mobile | Danh sách từ vựng yêu thích |
| PUT  | /api/vocabulary/:id/flashcard | Mobile | Thêm vào Flashcard để luyện tập |
| DELETE | /api/vocabulary/:id | Mobile | Xóa từ vựng yêu thích |
| GET  | /api/vocabulary/system | Mobile + Admin | Xem kho từ vựng hệ thống |
| POST/PUT/DELETE | /api/vocabulary/system/:id | Admin | Quản lý kho từ vựng hệ thống |

### Lịch sử hoạt động
| Method | Endpoint | Ai dùng | Mô tả |
|---|---|---|---|
| POST | /api/history | Mobile | Ghi lại 1 lượt dịch |
| GET  | /api/history | Mobile | Xem lịch sử dịch thuật cá nhân |
| DELETE | /api/history/:id | Mobile | Xóa 1 bản ghi lịch sử |
| GET  | /api/history/admin/all | Admin | Xem toàn bộ lịch sử hệ thống |
| DELETE | /api/history/admin/:id | Admin | Xóa bản ghi lịch sử bất kỳ |

### Quản trị hệ thống
| Method | Endpoint | Ai dùng | Mô tả |
|---|---|---|---|
| GET | /api/stats/users | Admin | Thống kê người dùng |
| GET | /api/stats/vocabulary | Admin | Thống kê từ vựng được lưu |
| POST/PUT/DELETE | /api/languages | Admin | Quản lý ngôn ngữ / model dịch hỗ trợ |

## 5. Ghi chú tích hợp Flutter

- Dùng `http` hoặc `dio` package, lưu JWT token bằng `flutter_secure_storage`.
- Các chức năng offline (chọn ngôn ngữ đã tải, Vosk STT, ML Kit TTS) xử lý hoàn toàn trên thiết bị — chỉ đồng bộ danh mục ngôn ngữ + lưu lịch sử/từ vựng lên backend khi có mạng.
- AI Assistant và tóm tắt hội thoại bắt buộc phải Online (gọi thẳng tới backend, backend proxy sang Gemini để giữ an toàn API key).

## 6. Việc tiếp theo có thể làm

- Viết Postman collection / OpenAPI spec để bạn test nhanh từng endpoint.
- Dựng Flutter project khung (auth flow + gọi các API trên).
- Dựng Web Admin (NodeJS + EJS/React) gọi các API `admin`.
