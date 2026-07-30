const multer = require('multer');
const path = require('path');
const fs = require('fs');

const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads', 'models');

// Đảm bảo thư mục lưu file tồn tại
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

const storage = multer.diskStorage({
  // QUAN TRỌNG: giữ nguyên tên file gốc (không thêm tiền tố), vì `vosk_flutter`
  // (ModelLoader) dựa vào tên file .zip để xác định đúng thư mục con chứa file
  // model bên trong sau khi giải nén (zip Vosk luôn có 1 thư mục con trùng tên
  // file, vd "vosk-model-small-en-us-0.15/"). Nếu đổi tên file lúc lưu, app sẽ
  // không tìm thấy thư mục model đúng -> lỗi "does not contain model files".
  // Để tránh trùng tên giữa các lần upload, mỗi file được đặt trong 1 thư mục
  // con riêng (theo timestamp) thay vì đổi tên file.
  destination: (req, file, cb) => {
    const subDir = path.join(UPLOAD_DIR, String(Date.now()));
    fs.mkdirSync(subDir, { recursive: true });
    cb(null, subDir);
  },
  filename: (req, file, cb) => {
    const safeName = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
    cb(null, safeName);
  },
});

// Model Vosk có thể khá lớn (model đầy đủ >1GB); giới hạn mặc định 800MB, chỉnh qua .env nếu cần
const MAX_UPLOAD_MB = parseInt(process.env.MAX_MODEL_UPLOAD_MB || '800', 10);

const uploadModelFile = multer({
  storage,
  limits: { fileSize: MAX_UPLOAD_MB * 1024 * 1024 },
});

module.exports = { uploadModelFile, UPLOAD_DIR };