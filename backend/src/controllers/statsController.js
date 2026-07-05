const User = require('../models/User');
const Vocabulary = require('../models/Vocabulary');
const TranslationHistory = require('../models/TranslationHistory');

// @desc    Thống kê người dùng (tổng số, mới trong 7/30 ngày, đang hoạt động...)
// @route   GET /api/stats/users
const getUserStats = async (req, res, next) => {
  try {
    const now = new Date();
    const sevenDaysAgo = new Date(now - 7 * 24 * 60 * 60 * 1000);
    const thirtyDaysAgo = new Date(now - 30 * 24 * 60 * 60 * 1000);

    const [total, activeCount, newLast7Days, newLast30Days, adminCount] = await Promise.all([
      User.countDocuments(),
      User.countDocuments({ isActive: true }),
      User.countDocuments({ createdAt: { $gte: sevenDaysAgo } }),
      User.countDocuments({ createdAt: { $gte: thirtyDaysAgo } }),
      User.countDocuments({ role: 'admin' }),
    ]);

    // Thống kê đăng ký theo ngày trong 30 ngày gần nhất (biểu đồ)
    const registrationsByDay = await User.aggregate([
      { $match: { createdAt: { $gte: thirtyDaysAgo } } },
      {
        $group: {
          _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
          count: { $sum: 1 },
        },
      },
      { $sort: { _id: 1 } },
    ]);

    res.json({
      total,
      activeCount,
      newLast7Days,
      newLast30Days,
      adminCount,
      registrationsByDay,
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Thống kê từ vựng được lưu (tổng số, top từ phổ biến, theo ngôn ngữ...)
// @route   GET /api/stats/vocabulary
const getVocabularyStats = async (req, res, next) => {
  try {
    const total = await Vocabulary.countDocuments();
    const inFlashcardCount = await Vocabulary.countDocuments({ inFlashcard: true });

    const topWords = await Vocabulary.aggregate([
      { $group: { _id: '$word', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
      { $limit: 10 },
    ]);

    const byTargetLanguage = await Vocabulary.aggregate([
      { $group: { _id: '$targetLanguage', count: { $sum: 1 } } },
      { $sort: { count: -1 } },
    ]);

    const totalTranslations = await TranslationHistory.countDocuments();

    res.json({
      total,
      inFlashcardCount,
      topWords,
      byTargetLanguage,
      totalTranslations,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { getUserStats, getVocabularyStats };
