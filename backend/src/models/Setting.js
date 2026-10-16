const mongoose = require('mongoose');

// Bảng cấu hình hệ thống dạng key-value (vd: geminiApiKey, geminiModel).
// Giá trị nhạy cảm được mã hóa (xem utils/crypto.js) trước khi lưu vào `value`.
const settingSchema = new mongoose.Schema(
  {
    key: { type: String, required: true, unique: true, trim: true },
    value: { type: String, default: '' },
    encrypted: { type: Boolean, default: false },
    updatedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Setting', settingSchema);
