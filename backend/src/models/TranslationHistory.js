const mongoose = require('mongoose');

const translationHistorySchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    sourceLanguage: { type: String, required: true },
    targetLanguage: { type: String, required: true },
    sourceText: { type: String, required: true },
    translatedText: { type: String, required: true },
    // Loại tương tác: dịch văn bản, dịch giọng nói, hội thoại AI
    type: { type: String, enum: ['text', 'speech', 'ai_chat'], default: 'text' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('TranslationHistory', translationHistorySchema);
