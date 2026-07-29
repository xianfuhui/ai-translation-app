const express = require('express');
const router = express.Router();
const apiClient = require('../services/apiClient');
const { requireAuth } = require('../middleware/requireAuth');

router.use(requireAuth);

// Xem toàn bộ lịch sử dịch thuật hệ thống
router.get('/history', async (req, res, next) => {
  try {
    const { page = 1, userId = '', from = '', to = '' } = req.query;
    const { data } = await apiClient(req).get('/history/admin/all', {
      params: { page, limit: 15, userId, from, to },
    });
    res.render('history/list', { ...data, userId, from, to });
  } catch (err) {
    next(err);
  }
});

// Xóa 1 bản ghi lịch sử
router.post('/history/:id/delete', async (req, res, next) => {
  try {
    await apiClient(req).delete(`/history/admin/${req.params.id}`);
    res.redirect('back');
  } catch (err) {
    next(err);
  }
});

module.exports = router;
