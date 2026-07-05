const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema(
  {
    role: { type: String, enum: ['user', 'assistant'], required: true },
    content: { type: String, required: true },
  },
  { _id: false, timestamps: true }
);

const aiConversationSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    title: { type: String, default: 'Cuộc hội thoại mới' },
    messages: [messageSchema],
    summary: { type: String }, // bản tóm tắt do Gemini tạo
  },
  { timestamps: true }
);

module.exports = mongoose.model('AIConversation', aiConversationSchema);
