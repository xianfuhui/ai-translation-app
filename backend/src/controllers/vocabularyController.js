const axios = require('axios');
const Vocabulary = require('../models/Vocabulary');
const SystemVocabulary = require('../models/SystemVocabulary');

// Tra từ điển online để lấy phiên âm (dấu phát âm) + âm thanh phát âm.
// Best-effort: không chặn luồng chính nếu tra từ điển lỗi/không tìm thấy.
const lookupPronunciation = async (word) => {
  try {
    const dictRes = await axios.get(`${process.env.DICTIONARY_API_BASE}/en/${encodeURIComponent(word)}`);
    const entry = dictRes.data?.[0];
    const phoneticEntry = entry?.phonetics?.find((p) => p.text) || entry?.phonetics?.[0];
    return {
      phonetic: entry?.phonetic || phoneticEntry?.text,
      audioUrl: entry?.phonetics?.find((p) => p.audio)?.audio,
    };
  } catch (e) {
    return { phonetic: undefined, audioUrl: undefined };
  }
};

// ===== Từ vựng yêu thích của người dùng (Mobile) =====

// @desc    Lưu từ vựng yêu thích (từ đoạn hội thoại hoặc tự nhập)
// @route   POST /api/vocabulary
const saveVocabulary = async (req, res, next) => {
  try {
    const { word, meaning, sourceLanguage, targetLanguage, source } = req.body;
    if (!word || !word.trim()) return res.status(400).json({ message: 'Vui lòng nhập từ vựng' });
    if (!meaning || !meaning.trim()) return res.status(400).json({ message: 'Vui lòng nhập nghĩa của từ vựng' });

    // Lấy phiên âm + âm thanh phát âm từ từ điển online (best-effort, không chặn nếu lỗi)
    const { phonetic, audioUrl } = await lookupPronunciation(word);

    const vocab = await Vocabulary.findOneAndUpdate(
      { user: req.user._id, word, targetLanguage },
      { meaning, sourceLanguage, targetLanguage, source: source || 'manual', audioUrl, phonetic },
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
const createSystemVocabulary = async (req, res, next) => {
  try {
    const { word, meaning } = req.body;
    if (!word || !word.trim()) return res.status(400).json({ message: 'Vui lòng nhập từ vựng' });
    if (!meaning || !meaning.trim()) return res.status(400).json({ message: 'Vui lòng nhập nghĩa của từ vựng' });

    // Lấy phiên âm + âm thanh phát âm từ từ điển online (best-effort, không chặn nếu lỗi)
    const { phonetic, audioUrl } = await lookupPronunciation(word);

    const item = await SystemVocabulary.create({ ...req.body, phonetic, audioUrl, createdBy: req.user._id });
    res.status(201).json(item);
  } catch (error) {
    next(error);
  }
};

// @desc    Admin sửa từ vựng hệ thống
// @route   PUT /api/vocabulary/system/:id
const updateSystemVocabulary = async (req, res, next) => {
  try {
    const updates = { ...req.body };
    // Nếu từ vựng thay đổi, tra lại phiên âm + âm thanh phát âm
    if (updates.word) {
      const { phonetic, audioUrl } = await lookupPronunciation(updates.word);
      updates.phonetic = phonetic;
      updates.audioUrl = audioUrl;
    }

    const item = await SystemVocabulary.findByIdAndUpdate(req.params.id, updates, { new: true });
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
  removeFromFlashcard,
  deleteVocabulary,
  getSystemVocabulary,
  createSystemVocabulary,
  updateSystemVocabulary,
  deleteSystemVocabulary,
};
