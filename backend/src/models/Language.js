const mongoose = require('mongoose');

const languageSchema = new mongoose.Schema(
  {
    code: { type: String, required: true, unique: true, trim: true }, // vd: "en", "vi", "ja"
    name: { type: String, required: true, trim: true }, // vd: "Tiếng Anh"
    // Model/engine dịch dùng cho ngôn ngữ này (offline model name, vd Vosk model, hoặc engine dịch)
    translationModel: { type: String, trim: true },
    voskModelName: { type: String, trim: true }, // model Vosk cho speech-to-text
    isActive: { type: Boolean, default: true },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Language', languageSchema);
