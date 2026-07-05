const TranslationHistory = require('../models/TranslationHistory');

// @desc    Lưu một bản ghi lịch sử dịch thuật (được gọi sau mỗi lần dịch)
// @route   POST /api/history
const createHistory = async (req, res, next) => {
  try {
    const { sourceLanguage, targetLanguage, sourceText, translatedText, type } = req.body;
    const record = await TranslationHistory.create({
      user: req.user._id,
      sourceLanguage,
      targetLanguage,
      sourceText,
      translatedText,
      type: type || 'text',
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
  getAllHistoryAdmin,
  deleteHistoryAdmin,
};
