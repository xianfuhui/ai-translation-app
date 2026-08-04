const mongoose = require('mongoose');

// 1 lượt nói/dịch bên trong 1 phiên dịch trực tiếp (Bắt đầu -> Dừng)
const segmentSchema = new mongoose.Schema(
  {
    sourceText: { type: String, required: true },
    translatedText: { type: String, required: true },
    // Thời điểm thực tế của lượt nói này (lấy giờ trên máy lúc nhận diện xong câu,
    // KHÔNG dùng timestamp mặc định của subdocument vì cả phiên chỉ được gửi lên
    // server 1 lần lúc bấm Dừng - nếu dùng mặc định thì mọi lượt sẽ trùng 1 giờ).
    at: { type: Date, default: Date.now },
  },
  { _id: false }
);

const translationHistorySchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    sourceLanguage: { type: String, required: true },
    targetLanguage: { type: String, required: true },
    // Dùng cho type 'text' / 'speech' (1 lượt dịch đơn lẻ)
    sourceText: { type: String },
    translatedText: { type: String },
    // Dùng cho type 'conversation': gộp toàn bộ các lượt nói trong 1 phiên
    // dịch trực tiếp (từ lúc bấm Bắt đầu đến lúc bấm Dừng) vào 1 mục lịch sử.
    segments: { type: [segmentSchema], default: undefined },
    // Giờ bấm Bắt đầu / Dừng của phiên (chỉ có với type 'conversation').
    // Lưu ý: `createdAt` (timestamps mặc định bên dưới) là thời điểm bản ghi được
    // LƯU lên server, tức là ~ giờ Dừng; `startedAt` mới là giờ Bắt đầu thật.
    startedAt: { type: Date },
    endedAt: { type: Date },
    // Loại tương tác: dịch văn bản, dịch giọng nói (1 câu), hội thoại AI,
    // hoặc 1 phiên dịch trực tiếp Bắt đầu/Dừng gồm nhiều lượt (conversation)
    type: { type: String, enum: ['text', 'speech', 'ai_chat', 'conversation'], default: 'text' },
    // Bản tóm tắt do AI tạo khi người dùng bấm nút LLM trên mục lịch sử này
    summary: { type: String },
  },
  { timestamps: true }
);

// Với type 'conversation' bắt buộc phải có ít nhất 1 lượt trong segments;
// với các type còn lại bắt buộc phải có sourceText/translatedText.
translationHistorySchema.pre('validate', function (next) {
  if (this.type === 'conversation') {
    if (!this.segments || this.segments.length === 0) {
      return next(new Error('Phiên hội thoại phải có ít nhất 1 lượt nói'));
    }
    // Nếu client không gửi startedAt/endedAt, suy ra từ thời điểm lượt nói đầu/cuối
    if (!this.startedAt) this.startedAt = this.segments[0].at || new Date();
    if (!this.endedAt) this.endedAt = this.segments[this.segments.length - 1].at || new Date();
  } else if (!this.sourceText || !this.translatedText) {
    return next(new Error('Vui lòng nhập đầy đủ văn bản gốc và văn bản dịch'));
  }
  next();
});

module.exports = mongoose.model('TranslationHistory', translationHistorySchema);
