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
npm run seed:admin        # tạo tài khoản admin đầu tiên
npm run seed:data         # (tùy chọn) tạo dữ liệu mẫu để kiểm thử
npm run dev                # hoặc: npm start
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

> Chọn ngôn ngữ, Speech-to-Text (Vosk), Text-to-Speech (ML Kit) chạy **offline trên thiết bị**, backend chỉ cung cấp cấu hình model qua API `/api/models` (xem mục 6), quản lý ngay trong Web Admin → trang **Ngôn ngữ & Model**.

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
| POST/PUT/DELETE | /api/languages | Admin | Quản lý ngôn ngữ hỗ trợ |
| GET | /api/models | Mobile + Admin | Danh sách model Vosk (STT) / ML Kit (dịch) khả dụng |
| POST/PUT/DELETE | /api/models/:id | Admin | Thêm/sửa/xóa model Vosk hoặc ML Kit |

## 5. Ghi chú tích hợp Flutter

- Dùng `http` hoặc `dio` package, lưu JWT token bằng `flutter_secure_storage`.
- Các chức năng offline (chọn ngôn ngữ đã tải, Vosk STT, ML Kit TTS) xử lý hoàn toàn trên thiết bị — chỉ đồng bộ danh mục ngôn ngữ + lưu lịch sử/từ vựng lên backend khi có mạng.
- AI Assistant và tóm tắt hội thoại bắt buộc phải Online (gọi thẳng tới backend, backend proxy sang Gemini để giữ an toàn API key).

## 6. Upload file model (Vosk/ML Kit)

Endpoint `POST/PUT /api/models` chấp nhận `multipart/form-data` với field file tên **`modelFile`** (tùy chọn, kèm các field text khác như `type`, `name`, `languageCode`, `identifier`...). File được lưu tại `backend/uploads/models/` và phục vụ tĩnh qua `/uploads/models/<tên file>`.

- Giới hạn dung lượng mặc định: **800MB** (model Vosk đầy đủ có thể khá lớn) — chỉnh qua biến môi trường `MAX_MODEL_UPLOAD_MB` trong `.env`.
- Khi xóa model hoặc thay file mới, backend **tự động xóa file cũ** trên đĩa để không rác dung lượng.
- Response trả về thêm trường `fileUrl` (đường dẫn tương đối) khi model có file — client (Mobile/Web Admin) tự ghép với domain backend để tải.

> **Lưu ý:** ML Kit Translation không hỗ trợ nạp model tùy chỉnh — file upload cho loại `mlkit` chỉ để lưu trữ/tham khảo, bản thân tính năng dịch trong Mobile App luôn dùng model chính chủ Google (tự tải theo mã ngôn ngữ). File upload cho loại `vosk` thì được Mobile App dùng thật (tải trực tiếp từ backend).

## 7. Dữ liệu mẫu để kiểm thử

```bash
npm run seed:data
```

Script này tạo sẵn (an toàn chạy lại nhiều lần, tự xóa dữ liệu mẫu cũ trước khi tạo lại):

| Loại dữ liệu | Nội dung |
|---|---|
| Ngôn ngữ | Tiếng Anh (en), Tiếng Việt (vi), Tiếng Nhật (ja) đang bật; Tiếng Hàn (ko) đang tắt để test trạng thái |
| Tài khoản user | `user1@example.com` / `User@123`, `user2@example.com` / `User@123` |
| Kho từ vựng hệ thống | 8 từ (en→vi, ja→vi), thuộc 3 chủ đề: giao tiếp, du lịch, công việc |
| Từ vựng yêu thích | 3 từ cho `user1`, 2 từ đã thêm vào Flashcard |
| Lịch sử dịch thuật | 3 bản ghi (2 của user1, 1 của user2), rải theo ngày để test lọc theo thời gian |
| Hội thoại AI | 1 hội thoại mẫu 4 tin nhắn kèm bản tóm tắt cho `user1` |
| Kho model | 3 model Vosk (en/vi/ja) + 3 model ML Kit (en/vi/ja), đều đang bật |

Dùng các tài khoản trên để đăng nhập test trên **Mobile App**; dùng tài khoản admin (từ `seed:admin`) để xem toàn bộ dữ liệu này trên **Web Admin**.

## 8. Việc tiếp theo có thể làm

- Viết Postman collection / OpenAPI spec để bạn test nhanh từng endpoint.
- Dựng Flutter project khung (auth flow + gọi các API trên).
- Dựng Web Admin (NodeJS + EJS/React) gọi các API `admin`.
