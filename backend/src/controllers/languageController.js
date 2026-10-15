const Language = require('../models/Language');
const Model = require('../models/Model');
const Vocabulary = require('../models/Vocabulary');
const TranslationHistory = require('../models/TranslationHistory');

// @desc    Lấy danh sách ngôn ngữ hỗ trợ (dùng cho Mobile chọn ngôn ngữ dịch)
// @route   GET /api/languages
const getLanguages = async (req, res, next) => {
  try {
    // Mobile chỉ cần ngôn ngữ đang hoạt động; Admin truyền ?all=true để thấy cả ngôn ngữ đã tắt
    const filter = req.query.all === 'true' ? {} : { isActive: true };
    const languages = await Language.find(filter).sort({ name: 1 });
    res.json(languages);
  } catch (error) {
    next(error);
  }
};

// @desc    Admin thêm ngôn ngữ / model dịch mới
// @route   POST /api/languages
const createLanguage = async (req, res, next) => {
  try {
    const language = await Language.create(req.body);
    res.status(201).json(language);
  } catch (error) {
    next(error);
  }
};

// @desc    Admin sửa ngôn ngữ / model dịch
// @route   PUT /api/languages/:id
const updateLanguage = async (req, res, next) => {
  try {
    const language = await Language.findByIdAndUpdate(req.params.id, req.body, { new: true });
    if (!language) return res.status(404).json({ message: 'Không tìm thấy ngôn ngữ' });
    res.json(language);
  } catch (error) {
    next(error);
  }
};

// @desc    Admin xóa ngôn ngữ — CÓ KIỂM TRA THAM CHIẾU MỀM trước khi xóa
// @route   DELETE /api/languages/:id
// Các collection khác tham chiếu ngôn ngữ bằng CHUỖI code (denormalization,
// không phải ObjectId) nên Mongo không tự bảo vệ gì cả. Nếu xóa 1 code đang
// được models / vocabularies / translationhistories dùng thì dữ liệu cũ thành
// mồ côi. Quy tắc: còn tham chiếu -> chặn xóa (409), gợi ý tắt isActive
// (soft delete — mobile vốn chỉ thấy ngôn ngữ isActive:true).
const deleteLanguage = async (req, res, next) => {
  try {
    const language = await Language.findById(req.params.id);
    if (!language) return res.status(404).json({ message: 'Không tìm thấy ngôn ngữ' });

    const code = language.code;
    const [inModels, inVocab, inHistory] = await Promise.all([
      Model.countDocuments({ languageCode: code }),
      Vocabulary.countDocuments({ $or: [{ sourceLanguage: code }, { targetLanguage: code }] }),
      TranslationHistory.countDocuments({ $or: [{ sourceLanguage: code }, { targetLanguage: code }] }),
    ]);

    const totalRefs = inModels + inVocab + inHistory;
    if (totalRefs > 0) {
      return res.status(409).json({
        message:
          `Không thể xóa "${language.name}" (${code}): đang được tham chiếu bởi ` +
          `${inModels} model, ${inVocab} từ vựng, ${inHistory} bản ghi lịch sử. ` +
          `Hãy TẮT (isActive=false) thay vì xóa để giữ toàn vẹn dữ liệu cũ.`,
        references: { models: inModels, vocabularies: inVocab, histories: inHistory },
      });
    }

    await language.deleteOne();
    res.json({ message: 'Đã xóa ngôn ngữ' });
  } catch (error) {
    next(error);
  }
};

module.exports = { getLanguages, createLanguage, updateLanguage, deleteLanguage };
