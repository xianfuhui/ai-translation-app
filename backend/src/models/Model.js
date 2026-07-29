const mongoose = require('mongoose');

const modelSchema = new mongoose.Schema(
  {
    type: { type: String, enum: ['vosk', 'mlkit'], required: true, index: true },
    name: { type: String, required: true, trim: true }, // Tên hiển thị, vd "Vosk English Small"
    languageCode: { type: String, required: true, trim: true }, // Mã BCP-47, vd "en", "vi", "ja"

    // Với Vosk: tên thư mục/gói model (vd "vosk-model-small-en-us-0.15")
    // Với ML Kit: mã ngôn ngữ ML Kit dùng để dịch (thường trùng languageCode, vd "en")
    identifier: { type: String, required: true, trim: true },

    // Link tải ngoài (vd trang chính chủ Vosk) - dùng khi KHÔNG upload file trực tiếp
    downloadUrl: { type: String, trim: true },

    // Kích thước model (MB) - tự tính lại nếu có upload file thật, hoặc admin tự nhập
    sizeMB: { type: Number },

    // Thông tin file model được Admin upload trực tiếp lên server (ưu tiên hơn downloadUrl nếu có)
    fileName: { type: String, trim: true }, // tên file lưu trên server (đã random hóa)
    originalFileName: { type: String, trim: true }, // tên file gốc lúc upload

    description: { type: String, trim: true },
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true }
);

modelSchema.index({ type: 1, languageCode: 1, identifier: 1 }, { unique: true });

// Trả thêm `fileUrl` (đường dẫn tương đối) khi có file đã upload, để client ghép với domain backend mà tải về
modelSchema.set('toJSON', {
  virtuals: true,
  transform: (doc, ret) => {
    ret.fileUrl = ret.fileName ? `/uploads/models/${ret.fileName}` : null;
    return ret;
  },
});

module.exports = mongoose.model('Model', modelSchema);
