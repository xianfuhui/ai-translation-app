const axios = require('axios');
const Vocabulary = require('../models/Vocabulary');
const SystemVocabulary = require('../models/SystemVocabulary');

// ===== Từ vựng yêu thích của người dùng (Mobile) =====

// @desc    Lưu từ vựng yêu thích (từ đoạn hội thoại hoặc tự nhập)
// @route   POST /api/vocabulary
const saveVocabulary = async (req, res, next) => {
  try {
    const { word, meaning, sourceLanguage, targetLanguage, source } = req.body;
    if (!word) return res.status(400).json({ message: 'Vui lòng nhập từ vựng' });

    // Lấy âm thanh phát âm từ từ điển online (best-effort, không chặn nếu lỗi)
    let audioUrl;
    try {
      const dictRes = await axios.get(`${process.env.DICTIONARY_API_BASE}/en/${encodeURIComponent(word)}`);
      audioUrl = dictRes.data?.[0]?.phonetics?.find((p) => p.audio)?.audio;
    } catch (e) {
      audioUrl = undefined;
    }

    const vocab = await Vocabulary.findOneAndUpdate(
      { user: req.user._id, word, targetLanguage },
      { meaning, sourceLanguage, targetLanguage, source: source || 'manual', audioUrl },
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
    res.json(list);
  } catch (error) {
    next(error);
  }
};

// @desc    Admin thêm từ vựng hệ thống
// @route   POST /api/vocabulary/system
const createSystemVocabulary = async (req, res, next) => {
  try {
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
    const item = await SystemVocabulary.findByIdAndUpdate(req.params.id, req.body, { new: true });
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

module.exports = {
  saveVocabulary,
  getMyVocabulary,
  addToFlashcard,
  deleteVocabulary,
  getSystemVocabulary,
  createSystemVocabulary,
  updateSystemVocabulary,
  deleteSystemVocabulary,
};
