const TranslationHistory = require('../models/TranslationHistory');
const { callGemini, truncateForLlm } = require('../utils/gemini');

// @desc    Lưu một bản ghi lịch sử dịch thuật
// @route   POST /api/history
// - type 'text' | 'speech' | 'ai_chat': 1 lượt dịch đơn -> cần sourceText, translatedText
// - type 'conversation': 1 phiên dịch trực tiếp Bắt đầu/Dừng, gộp nhiều lượt -> cần segments (mảng)
const createHistory = async (req, res, next) => {
  try {
    const { sourceLanguage, targetLanguage, sourceText, translatedText, type, segments, startedAt, endedAt } = req.body;

    if (type === 'conversation') {
      if (!Array.isArray(segments) || segments.length === 0) {
        return res.status(400).json({ message: 'Phiên hội thoại phải có ít nhất 1 lượt nói' });
      }
    }

    const record = await TranslationHistory.create({
      user: req.user._id,
      sourceLanguage,
      targetLanguage,
      sourceText,
      translatedText,
      type: type || 'text',
      segments: type === 'conversation' ? segments : undefined,
      startedAt: type === 'conversation' ? startedAt : undefined,
      endedAt: type === 'conversation' ? endedAt : undefined,
    });
    res.status(201).json(record);
  } catch (error) {
    next(error);
  }
};

// @desc    Xem lịch sử dịch thuật của chính người dùng (Mobile)
// @route   GET /api/history?page=1&limit=20
const getMyHistory = async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;

    const [records, total] = await Promise.all([
      TranslationHistory.find({ user: req.user._id })
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit),
      TranslationHistory.countDocuments({ user: req.user._id }),
    ]);

    res.json({ records, total, page, totalPages: Math.ceil(total / limit) });
  } catch (error) {
    next(error);
  }
};

// @desc    Xóa 1 bản ghi lịch sử của chính mình
// @route   DELETE /api/history/:id
const deleteMyHistory = async (req, res, next) => {
  try {
    const record = await TranslationHistory.findOneAndDelete({ _id: req.params.id, user: req.user._id });
    if (!record) return res.status(404).json({ message: 'Không tìm thấy bản ghi lịch sử' });
    res.json({ message: 'Đã xóa bản ghi lịch sử' });
  } catch (error) {
    next(error);
  }
};

// @desc    Dùng LLM (Gemini) tóm tắt nội dung 1 mục lịch sử (đặc biệt hữu ích với
//          mục type 'conversation' gồm nhiều lượt nói trong 1 phiên Bắt đầu/Dừng).
//          LƯU Ý: tính năng LLM có giới hạn số ký tự đầu vào -> nội dung quá dài
//          sẽ tự động được cắt bớt trước khi gửi (xem utils/gemini.js).
// @route   POST /api/history/:id/summarize
const summarizeHistory = async (req, res, next) => {
  try {
    const record = await TranslationHistory.findOne({ _id: req.params.id, user: req.user._id });
    if (!record) return res.status(404).json({ message: 'Không tìm thấy bản ghi lịch sử' });

    let transcript;
    if (record.type === 'conversation' && record.segments?.length) {
      transcript = record.segments
        .map((s, i) => `[${i + 1}] Gốc: ${s.sourceText}\n    Dịch: ${s.translatedText}`)
        .join('\n');
    } else {
      transcript = `Gốc: ${record.sourceText}\nDịch: ${record.translatedText}`;
    }

    const { text: safeTranscript, truncated } = truncateForLlm(transcript);

    const prompt =
      `Hãy tóm tắt ngắn gọn, súc tích (khoảng 3-5 câu) nội dung chính của đoạn hội thoại/dịch thuật ` +
      `sau đây bằng tiếng Việt${truncated ? ' (một phần nội dung đã được lược bớt do vượt giới hạn ký tự của LLM)' : ''}:\n\n${safeTranscript}`;

    const summary = await callGemini([{ role: 'user', parts: [{ text: prompt }] }]);

    record.summary = summary;
    await record.save();

    res.json({ id: record._id, summary, truncated });
  } catch (error) {
    if (error.response) {
      return res.status(502).json({ message: 'Lỗi khi gọi LLM để tóm tắt', detail: error.response.data });
    }
    next(error);
  }
};

// ===== Admin: Quản lý dữ liệu lịch sử toàn hệ thống =====

// @desc    Admin xem toàn bộ lịch sử hệ thống (lọc theo user, khoảng thời gian...)
// @route   GET /api/history/admin/all
const getAllHistoryAdmin = async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const { userId, from, to } = req.query;

    const filter = {};
    if (userId) filter.user = userId;
    if (from || to) {
      filter.createdAt = {};
      if (from) filter.createdAt.$gte = new Date(from);
      if (to) filter.createdAt.$lte = new Date(to);
    }

    const [records, total] = await Promise.all([
      TranslationHistory.find(filter)
        .populate('user', 'fullName email')
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit),
      TranslationHistory.countDocuments(filter),
    ]);

    res.json({ records, total, page, totalPages: Math.ceil(total / limit) });
  } catch (error) {
    next(error);
  }
};

// @desc    Admin xóa bản ghi lịch sử bất kỳ
// @route   DELETE /api/history/admin/:id
const deleteHistoryAdmin = async (req, res, next) => {
  try {
    const record = await TranslationHistory.findByIdAndDelete(req.params.id);
    if (!record) return res.status(404).json({ message: 'Không tìm thấy bản ghi lịch sử' });
    res.json({ message: 'Đã xóa bản ghi lịch sử' });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  createHistory,
  getMyHistory,
  deleteMyHistory,
  summarizeHistory,
  getAllHistoryAdmin,
  deleteHistoryAdmin,
};
