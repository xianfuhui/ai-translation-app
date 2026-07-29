const multer = require('multer');
const path = require('path');
const fs = require('fs');

const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads', 'models');

// Đảm bảo thư mục lưu file tồn tại
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const safeName = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
    cb(null, `${Date.now()}-${safeName}`);
  },
});

// Model Vosk có thể khá lớn (model đầy đủ >1GB); giới hạn mặc định 800MB, chỉnh qua .env nếu cần
const MAX_UPLOAD_MB = parseInt(process.env.MAX_MODEL_UPLOAD_MB || '800', 10);

const uploadModelFile = multer({
  storage,
  limits: { fileSize: MAX_UPLOAD_MB * 1024 * 1024 },
});

module.exports = { uploadModelFile, UPLOAD_DIR };
