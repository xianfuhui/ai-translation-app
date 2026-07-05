const mongoose = require('mongoose');

const systemVocabularySchema = new mongoose.Schema(
  {
    word: { type: String, required: true, trim: true },
    meaning: { type: String, trim: true },
    sourceLanguage: { type: String, trim: true },
    targetLanguage: { type: String, trim: true },
    category: { type: String, trim: true }, // vd: chủ đề (du lịch, công việc...)
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, // admin tạo
  },
  { timestamps: true }
);

module.exports = mongoose.model('SystemVocabulary', systemVocabularySchema);
