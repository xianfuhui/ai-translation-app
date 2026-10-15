const express = require('express');
const router = express.Router();
const multer = require('multer');
const apiClient = require('../services/apiClient');
const apiUpload = require('../services/apiUpload');
const { requireAuth } = require('../middleware/requireAuth');

router.use(requireAuth);

// Multer memory storage để nhận file Excel từ form admin rồi forward sang backend
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
});

// Danh sách từ vựng hệ thống
router.get('/vocabulary', async (req, res, next) => {
  try {
    const { search = '', category = '' } = req.query;
    const { data } = await apiClient(req).get('/vocabulary/system', { params: { search, category } });
    res.render('vocabulary/list', { items: data, search, category, importResult: null });
  } catch (err) {
    next(err);
  }
});

// Thêm từ vựng hệ thống mới (form đơn)
router.post('/vocabulary', async (req, res, next) => {
  try {
    const { word, meaning, sourceLanguage, targetLanguage, category, phonetic, audioUrl } = req.body;
    await apiClient(req).post('/vocabulary/system', {
      word, meaning, sourceLanguage, targetLanguage, category, phonetic, audioUrl,
    });
    res.redirect('/vocabulary');
  } catch (err) {
    next(err);
  }
});

// Import từ vựng từ file Excel
router.post('/vocabulary/import', upload.single('file'), async (req, res, next) => {
  try {
    const result = await apiUpload(req, 'post', '/vocabulary/system/import', {}, req.file);
    const { search = '', category = '' } = req.query;
    const { data: items } = await apiClient(req).get('/vocabulary/system', { params: { search, category } });
    res.render('vocabulary/list', { items, search, category, importResult: result });
  } catch (err) {
    // Hiển thị lỗi inline thay vì crash
    const { search = '', category = '' } = req.query;
    let items = [];
    try {
      const { data } = await apiClient(req).get('/vocabulary/system', { params: { search, category } });
      items = data;
    } catch (_) {}
    const importResult = {
      error: true,
      message: err?.response?.data?.message || err.message || 'Lỗi import file',
      errors: err?.response?.data?.errors,
    };
    res.render('vocabulary/list', { items, search, category, importResult });
  }
});

// Sửa từ vựng hệ thống
router.post('/vocabulary/:id/update', async (req, res, next) => {
  try {
    const { word, meaning, sourceLanguage, targetLanguage, category, phonetic, audioUrl } = req.body;
    await apiClient(req).put(`/vocabulary/system/${req.params.id}`, {
      word, meaning, sourceLanguage, targetLanguage, category, phonetic, audioUrl,
    });
    res.redirect('/vocabulary');
  } catch (err) {
    next(err);
  }
});

// Xóa từ vựng hệ thống
router.post('/vocabulary/:id/delete', async (req, res, next) => {
  try {
    await apiClient(req).delete(`/vocabulary/system/${req.params.id}`);
    res.redirect('/vocabulary');
  } catch (err) {
    next(err);
  }
});

module.exports = router;
