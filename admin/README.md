# Web Admin (NodeJS) - Quản trị hệ thống Dịch ngôn ngữ & Từ vựng

Ứng dụng web server-rendered (Express + EJS) dành riêng cho **Admin**, gọi tới Backend API (`backend/`) đã xây dựng trước đó.

## 1. Yêu cầu

- Đã chạy được `backend/` (xem README trong đó) tại `http://localhost:5000`
- Đã có ít nhất 1 tài khoản admin (chạy `npm run seed:admin` trong `backend/`)

## 2. Cài đặt & chạy

```bash
cd admin-web
cp .env.example .env      # chỉnh BACKEND_API_URL nếu backend chạy port khác
npm install
npm run dev                # hoặc: npm start
```

Mặc định chạy tại: **http://localhost:4000**

## 3. Đăng nhập

Vào `http://localhost:4000/login`, dùng email/mật khẩu admin đã seed (mặc định `admin@example.com` / `Admin@123` nếu bạn chưa đổi trong `.env` của backend).

> Chỉ tài khoản có `role: "admin"` mới đăng nhập được vào trang này — nếu dùng tài khoản `user` (từ Mobile) sẽ bị từ chối.

## 4. Các trang / chức năng

| Trang | Route | Chức năng |
|---|---|---|
| Tổng quan | `/dashboard` | Thống kê người dùng + từ vựng (POM: xem thống kê) |
| Người dùng | `/users` | Tìm kiếm, đổi vai trò, khóa/mở khóa, xóa tài khoản |
| Kho từ vựng | `/vocabulary` | Thêm/xóa từ vựng hệ thống, tìm kiếm theo chủ đề |
| Lịch sử dịch | `/history` | Xem & xóa lịch sử dịch thuật toàn hệ thống, lọc theo ngày |
| Ngôn ngữ | `/languages` | Thêm/bật-tắt/xóa ngôn ngữ và model dịch (Vosk, model dịch) hỗ trợ |

## 5. Kiến trúc

```
admin-web/
├── server.js                 # Entry point, session, gắn route
├── public/css/style.css      # Giao diện (thiết kế "sổ tay từ điển")
└── src/
    ├── middleware/requireAuth.js
    ├── services/apiClient.js  # axios gọi backend, tự đính JWT từ session
    ├── routes/                # auth, dashboard, users, vocabulary, history, languages
    └── views/                 # EJS templates (partials/head, partials/sidebar, các trang)
```

Admin đăng nhập → token JWT lưu trong `express-session` (server-side, cookie chỉ chứa session id) → mọi request tới backend đều đính kèm token này qua header `Authorization`.

## 6. Việc tiếp theo có thể làm

- Trang chỉnh sửa (edit) chi tiết cho từ vựng hệ thống / ngôn ngữ (hiện tại sửa nhanh qua nút bật-tắt, có thể mở rộng thành form riêng).
- Biểu đồ trực quan cho `registrationsByDay` (đã có sẵn dữ liệu từ API `/api/stats/users`).
- Phân trang cho trang Kho từ vựng.
