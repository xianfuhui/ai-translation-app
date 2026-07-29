const mongoose = require('mongoose');

const languageSchema = new mongoose.Schema(
  {
    code: { type: String, required: true, unique: true, trim: true }, // vd: "en", "vi", "ja"
    name: { type: String, required: true, trim: true }, // vd: "Tiếng Anh"
    isActive: { type: Boolean, default: true },
    // Model Vosk (STT) và ML Kit (dịch) cho ngôn ngữ này được quản lý riêng
    // trong collection `Model` (lọc theo `languageCode` = `code` ở đây),
    // xem src/controllers/modelController.js
  },
  { timestamps: true }
);

module.exports = mongoose.model('Language', languageSchema);
