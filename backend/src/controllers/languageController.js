const Language = require('../models/Language');

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

// @desc    Admin xóa ngôn ngữ / model dịch
// @route   DELETE /api/languages/:id
const deleteLanguage = async (req, res, next) => {
  try {
    const language = await Language.findByIdAndDelete(req.params.id);
    if (!language) return res.status(404).json({ message: 'Không tìm thấy ngôn ngữ' });
    res.json({ message: 'Đã xóa ngôn ngữ' });
  } catch (error) {
    next(error);
  }
};

module.exports = { getLanguages, createLanguage, updateLanguage, deleteLanguage };
