const Vocabulary = require('../models/Vocabulary');
const SystemVocabulary = require('../models/SystemVocabulary');
const xlsx = require('xlsx');

// ===== Từ vựng yêu thích của người dùng (Mobile) =====

// @desc    Lưu từ vựng yêu thích (từ đoạn hội thoại hoặc tự nhập)
// @route   POST /api/vocabulary
const saveVocabulary = async (req, res, next) => {
  try {
    const { word, meaning, sourceLanguage, targetLanguage, source } = req.body;
    if (!word || !word.trim()) return res.status(400).json({ message: 'Vui lòng nhập từ vựng' });
    if (!meaning || !meaning.trim()) return res.status(400).json({ message: 'Vui lòng nhập nghĩa của từ vựng' });

    const vocab = await Vocabulary.findOneAndUpdate(
      { user: req.user._id, word, targetLanguage },
      { meaning, sourceLanguage, targetLanguage, source: source || 'manual' },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );

    res.status(201).json(vocab);
  } catch (error) {
    next(error);
  }
};

// @desc    Lấy danh sách từ vựng yêu thích của người dùng
// @route   GET /api/vocabulary
const getMyVocabulary = async (req, res, next) => {
  try {
    const { inFlashcard } = req.query;
    const filter = { user: req.user._id };
    if (inFlashcard !== undefined) filter.inFlashcard = inFlashcard === 'true';

    const vocabList = await Vocabulary.find(filter).sort({ createdAt: -1 });
    res.json(vocabList);
  } catch (error) {
    next(error);
  }
};

// @desc    Thêm từ vựng yêu thích vào mục Flashcard để luyện tập
// @route   PUT /api/vocabulary/:id/flashcard
const addToFlashcard = async (req, res, next) => {
  try {
    const vocab = await Vocabulary.findOneAndUpdate(
      { _id: req.params.id, user: req.user._id },
      { inFlashcard: true },
      { new: true }
    );
    if (!vocab) return res.status(404).json({ message: 'Không tìm thấy từ vựng' });
    res.json(vocab);
  } catch (error) {
    next(error);
  }
};

// @desc    Bỏ từ vựng ra khỏi mục Flashcard
// @route   DELETE /api/vocabulary/:id/flashcard
const removeFromFlashcard = async (req, res, next) => {
  try {
    const vocab = await Vocabulary.findOneAndUpdate(
      { _id: req.params.id, user: req.user._id },
      { inFlashcard: false },
      { new: true }
    );
    if (!vocab) return res.status(404).json({ message: 'Không tìm thấy từ vựng' });
    res.json(vocab);
  } catch (error) {
    next(error);
  }
};

// @desc    Xóa từ vựng yêu thích
// @route   DELETE /api/vocabulary/:id
const deleteVocabulary = async (req, res, next) => {
  try {
    const vocab = await Vocabulary.findOneAndDelete({ _id: req.params.id, user: req.user._id });
    if (!vocab) return res.status(404).json({ message: 'Không tìm thấy từ vựng' });
    res.json({ message: 'Đã xóa từ vựng' });
  } catch (error) {
    next(error);
  }
};

// ===== Kho từ vựng hệ thống (Admin quản lý, User có thể xem/tra cứu) =====

// @desc    Lấy danh sách từ vựng hệ thống (User & Admin)
// @route   GET /api/vocabulary/system
const getSystemVocabulary = async (req, res, next) => {
  try {
    const { search, category } = req.query;
    const filter = {};
    if (search) filter.word = new RegExp(search, 'i');
    if (category) filter.category = category;

    const list = await SystemVocabulary.find(filter).sort({ createdAt: -1 });

    // Đánh dấu những từ đã có trong sổ tay cá nhân của user để hiển thị trạng thái "đã thêm"
    const myWords = await Vocabulary.find({ user: req.user._id }).select('word targetLanguage');
    const mySet = new Set(
      myWords.map((v) => `${v.word.trim().toLowerCase()}|${(v.targetLanguage || '').toLowerCase()}`)
    );

    const result = list.map((item) => {
      const obj = item.toObject();
      obj.inMyVocabulary = mySet.has(
        `${item.word.trim().toLowerCase()}|${(item.targetLanguage || '').toLowerCase()}`
      );
      return obj;
    });

    res.json(result);
  } catch (error) {
    next(error);
  }
};

// @desc    Admin thêm từ vựng hệ thống
// @route   POST /api/vocabulary/system
// Body: word, meaning, sourceLanguage, targetLanguage, category, phonetic, audioUrl
const createSystemVocabulary = async (req, res, next) => {
  try {
    const { word, meaning } = req.body;
    if (!word || !word.trim()) return res.status(400).json({ message: 'Vui lòng nhập từ vựng' });
    if (!meaning || !meaning.trim()) return res.status(400).json({ message: 'Vui lòng nhập nghĩa của từ vựng' });

    const item = await SystemVocabulary.create({ ...req.body, createdBy: req.user._id });
    res.status(201).json(item);
  } catch (error) {
    next(error);
  }
};

// @desc    Admin sửa từ vựng hệ thống
// @route   PUT /api/vocabulary/system/:id
const updateSystemVocabulary = async (req, res, next) => {
  try {
    const item = await SystemVocabulary.findByIdAndUpdate(req.params.id, { ...req.body }, { new: true });
    if (!item) return res.status(404).json({ message: 'Không tìm thấy từ vựng hệ thống' });
    res.json(item);
  } catch (error) {
    next(error);
  }
};

// @desc    Admin xóa từ vựng hệ thống
// @route   DELETE /api/vocabulary/system/:id
const deleteSystemVocabulary = async (req, res, next) => {
  try {
    const item = await SystemVocabulary.findByIdAndDelete(req.params.id);
    if (!item) return res.status(404).json({ message: 'Không tìm thấy từ vựng hệ thống' });
    res.json({ message: 'Đã xóa từ vựng hệ thống' });
  } catch (error) {
    next(error);
  }
};

// @desc    Lấy danh sách chủ đề (categories) có trong kho từ vựng hệ thống
// @route   GET /api/vocabulary/system/categories
const getSystemCategories = async (req, res, next) => {
  try {
    const categories = await SystemVocabulary.distinct('category', {
      category: { $exists: true, $ne: null, $ne: '' },
    });
    res.json(categories.sort());
  } catch (error) {
    next(error);
  }
};

// @desc    Admin import từ vựng hệ thống từ file Excel
// @route   POST /api/vocabulary/system/import
// Columns (header row): word, meaning, sourceLanguage, targetLanguage, category, phonetic, audioUrl
// "word" và "meaning" là bắt buộc; các cột còn lại tùy chọn.
// Nếu từ đã tồn tại (word + targetLanguage) thì bỏ qua (không ghi đè).
const importSystemVocabulary = async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'Vui lòng tải lên file Excel (.xlsx, .xls)' });

    const workbook = xlsx.read(req.file.buffer, { type: 'buffer' });
    const sheetName = workbook.SheetNames[0];
    const rows = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName], { defval: '' });

    if (!rows.length) return res.status(400).json({ message: 'File Excel không có dữ liệu' });

    const ALLOWED = ['word', 'meaning', 'sourceLanguage', 'targetLanguage', 'category', 'phonetic', 'audioUrl'];

    const errors = [];
    const toInsert = [];

    rows.forEach((row, i) => {
      const rowNum = i + 2; // +2 vì row 1 là header
      const word = String(row.word || '').trim();
      const meaning = String(row.meaning || '').trim();
      if (!word) { errors.push(`Dòng ${rowNum}: thiếu "word"`); return; }
      if (!meaning) { errors.push(`Dòng ${rowNum}: thiếu "meaning"`); return; }

      const doc = { createdBy: req.user._id };
      ALLOWED.forEach((key) => {
        const val = String(row[key] || '').trim();
        if (val) doc[key] = val;
      });
      toInsert.push(doc);
    });

    if (errors.length && !toInsert.length) {
      return res.status(400).json({ message: 'File có lỗi dữ liệu', errors });
    }

    // insertMany với ordered:false để bỏ qua duplicate (unique index word+targetLanguage nếu có)
    // Dùng upsert riêng từng cái để đảm bảo không ghi đè dữ liệu cũ
    let inserted = 0;
    let skipped = 0;
    for (const doc of toInsert) {
      const filter = { word: doc.word, targetLanguage: doc.targetLanguage || '' };
      const existing = await SystemVocabulary.findOne(filter);
      if (existing) { skipped++; continue; }
      await SystemVocabulary.create(doc);
      inserted++;
    }

    res.json({
      message: `Import thành công: ${inserted} từ mới, ${skipped} từ đã tồn tại bị bỏ qua.`,
      inserted,
      skipped,
      errors: errors.length ? errors : undefined,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = {
  saveVocabulary,
  getMyVocabulary,
  addToFlashcard,
  removeFromFlashcard,
  deleteVocabulary,
  getSystemVocabulary,
  createSystemVocabulary,
  updateSystemVocabulary,
  deleteSystemVocabulary,
  getSystemCategories,
  importSystemVocabulary,
};
