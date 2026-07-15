const express = require('express');
const router = express.Router();
const apiClient = require('../services/apiClient');
const { requireAuth } = require('../middleware/requireAuth');

router.use(requireAuth);

// Danh sách ngôn ngữ hỗ trợ
router.get('/languages', async (req, res, next) => {
  try {
    const { data } = await apiClient(req).get('/languages', { params: { all: true } });
    res.render('languages/list', { items: data });
  } catch (err) {
    next(err);
  }
});

// Thêm ngôn ngữ / model dịch mới
router.post('/languages', async (req, res, next) => {
  try {
    const { code, name, translationModel, voskModelName } = req.body;
    await apiClient(req).post('/languages', { code, name, translationModel, voskModelName });
    res.redirect('/languages');
  } catch (err) {
    next(err);
  }
});

// Sửa ngôn ngữ / model dịch
router.post('/languages/:id/update', async (req, res, next) => {
  try {
    const { code, name, translationModel, voskModelName, isActive } = req.body;
    await apiClient(req).put(`/languages/${req.params.id}`, {
      code,
      name,
      translationModel,
      voskModelName,
      isActive: isActive === 'true',
    });
    res.redirect('/languages');
  } catch (err) {
    next(err);
  }
});

// Xóa ngôn ngữ
router.post('/languages/:id/delete', async (req, res, next) => {
  try {
    await apiClient(req).delete(`/languages/${req.params.id}`);
    res.redirect('/languages');
  } catch (err) {
    next(err);
  }
});

module.exports = router;
