const axios = require('axios');
const AIConversation = require('../models/AIConversation');

const GEMINI_API_URL = (model) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

// Gọi Gemini API với danh sách nội dung (contents)
const callGemini = async (contents) => {
  const model = process.env.GEMINI_MODEL || 'gemini-2.0-flash';
  const response = await axios.post(
    `${GEMINI_API_URL(model)}?key=${process.env.GEMINI_API_KEY}`,
    { contents },
    { headers: { 'Content-Type': 'application/json' } }
  );
  return response.data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
};

// @desc    Gửi tin nhắn hội thoại với AI (tạo mới hoặc tiếp tục conversationId)
// @route   POST /api/ai/chat
// body: { conversationId?, message }
const chat = async (req, res, next) => {
  try {
    const { conversationId, message } = req.body;
    if (!message) return res.status(400).json({ message: 'Vui lòng nhập nội dung tin nhắn' });

    let conversation;
    if (conversationId) {
      conversation = await AIConversation.findOne({ _id: conversationId, user: req.user._id });
      if (!conversation) return res.status(404).json({ message: 'Không tìm thấy hội thoại' });
    } else {
      conversation = await AIConversation.create({ user: req.user._id, messages: [] });
    }

    conversation.messages.push({ role: 'user', content: message });

    // Chuyển lịch sử hội thoại sang định dạng Gemini "contents"
    const contents = conversation.messages.map((m) => ({
      role: m.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: m.content }],
    }));

    const aiReply = await callGemini(contents);
    conversation.messages.push({ role: 'assistant', content: aiReply });

    // Đặt tiêu đề tự động theo tin nhắn đầu tiên nếu chưa có
    if (conversation.messages.length === 2) {
      conversation.title = message.slice(0, 50);
    }

    await conversation.save();

    res.json({ conversationId: conversation._id, reply: aiReply });
  } catch (error) {
    if (error.response) {
      console.error('Gemini API error:', error.response.data);
      return res.status(502).json({ message: 'Lỗi khi gọi Gemini API', detail: error.response.data });
    }
    next(error);
  }
};

// @desc    Tóm tắt một hội thoại đã có
// @route   POST /api/ai/summarize/:conversationId
const summarize = async (req, res, next) => {
  try {
    const conversation = await AIConversation.findOne({
      _id: req.params.conversationId,
      user: req.user._id,
    });
    if (!conversation) return res.status(404).json({ message: 'Không tìm thấy hội thoại' });

    const transcript = conversation.messages
      .map((m) => `${m.role === 'user' ? 'Người dùng' : 'AI'}: ${m.content}`)
      .join('\n');

    const prompt = `Hãy tóm tắt ngắn gọn, súc tích nội dung chính của cuộc hội thoại sau bằng tiếng Việt:\n\n${transcript}`;

    const summary = await callGemini([{ role: 'user', parts: [{ text: prompt }] }]);

    conversation.summary = summary;
    await conversation.save();

    res.json({ conversationId: conversation._id, summary });
  } catch (error) {
    if (error.response) {
      return res.status(502).json({ message: 'Lỗi khi gọi Gemini API', detail: error.response.data });
    }
    next(error);
  }
};

// @desc    Lấy danh sách hội thoại của người dùng hiện tại
// @route   GET /api/ai/conversations
const getConversations = async (req, res, next) => {
  try {
    const conversations = await AIConversation.find({ user: req.user._id })
      .select('title summary createdAt updatedAt')
      .sort({ updatedAt: -1 });
    res.json(conversations);
  } catch (error) {
    next(error);
  }
};

// @desc    Lấy chi tiết 1 hội thoại (kèm toàn bộ tin nhắn)
// @route   GET /api/ai/conversations/:id
const getConversationById = async (req, res, next) => {
  try {
    const conversation = await AIConversation.findOne({ _id: req.params.id, user: req.user._id });
    if (!conversation) return res.status(404).json({ message: 'Không tìm thấy hội thoại' });
    res.json(conversation);
  } catch (error) {
    next(error);
  }
};

module.exports = { chat, summarize, getConversations, getConversationById };
