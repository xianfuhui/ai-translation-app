const express = require('express');
const router = express.Router();
const apiClient = require('../services/apiClient');
const { requireAuth } = require('../middleware/requireAuth');

router.use(requireAuth);

// Danh sách từ vựng hệ thống
router.get('/vocabulary', async (req, res, next) => {
  try {
    const { search = '', category = '' } = req.query;
    const { data } = await apiClient(req).get('/vocabulary/system', { params: { search, category } });
    res.render('vocabulary/list', { items: data, search, category });
  } catch (err) {
    next(err);
  }
});

// Thêm từ vựng hệ thống mới
router.post('/vocabulary', async (req, res, next) => {
  try {
    const { word, meaning, sourceLanguage, targetLanguage, category } = req.body;
    await apiClient(req).post('/vocabulary/system', { word, meaning, sourceLanguage, targetLanguage, category });
    res.redirect('/vocabulary');
  } catch (err) {
    next(err);
  }
});

// Sửa từ vựng hệ thống
router.post('/vocabulary/:id/update', async (req, res, next) => {
  try {
    const { word, meaning, sourceLanguage, targetLanguage, category } = req.body;
    await apiClient(req).put(`/vocabulary/system/${req.params.id}`, {
      word,
      meaning,
      sourceLanguage,
      targetLanguage,
      category,
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
