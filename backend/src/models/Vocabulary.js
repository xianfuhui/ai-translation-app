const mongoose = require('mongoose');

const vocabularySchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    word: { type: String, required: true, trim: true },
    meaning: { type: String, trim: true },
    sourceLanguage: { type: String, trim: true },
    targetLanguage: { type: String, trim: true },
    // Nguồn thêm từ: từ đoạn hội thoại (click chọn) hoặc tự nhập tay
    source: { type: String, enum: ['conversation', 'manual'], default: 'manual' },
    // Đánh dấu đã thêm vào Flashcard để luyện tập chưa
    inFlashcard: { type: Boolean, default: false },
    audioUrl: { type: String }, // âm thanh phát âm lấy từ từ điển online
  },
  { timestamps: true }
);

vocabularySchema.index({ user: 1, word: 1, targetLanguage: 1 }, { unique: true });

module.exports = mongoose.model('Vocabulary', vocabularySchema);
