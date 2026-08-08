const mongoose = require('mongoose');

const systemVocabularySchema = new mongoose.Schema(
  {
    word: { type: String, required: true, trim: true },
    meaning: { type: String, required: true, trim: true },
    sourceLanguage: { type: String, trim: true },
    targetLanguage: { type: String, trim: true },
    category: { type: String, trim: true }, // vd: chủ đề (du lịch, công việc...)
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, // admin tạo
    audioUrl: { type: String }, // âm thanh phát âm lấy từ từ điển online
    phonetic: { type: String }, // phiên âm (dấu phát âm), vd: /wɜːrd/, lấy từ từ điển online
  },
  { timestamps: true }
);

module.exports = mongoose.model('SystemVocabulary', systemVocabularySchema);
