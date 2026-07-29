const express = require('express');
const router = express.Router();
const apiClient = require('../services/apiClient');
const { requireAuth } = require('../middleware/requireAuth');

router.use(requireAuth);

// Danh sách người dùng (tìm kiếm + phân trang)
router.get('/users', async (req, res, next) => {
  try {
    const { page = 1, search = '' } = req.query;
    const { data } = await apiClient(req).get('/users', { params: { page, search, limit: 15 } });
    res.render('users/list', { ...data, search });
  } catch (err) {
    next(err);
  }
});

// Cập nhật user: đổi vai trò / khóa-mở khóa
router.post('/users/:id/update', async (req, res, next) => {
  try {
    const { role, isActive } = req.body;
    await apiClient(req).put(`/users/${req.params.id}`, {
      role,
      isActive: isActive === 'true',
    });
    res.redirect('back');
  } catch (err) {
    next(err);
  }
});

// Xóa user
router.post('/users/:id/delete', async (req, res, next) => {
  try {
    await apiClient(req).delete(`/users/${req.params.id}`);
    res.redirect('/users');
  } catch (err) {
    next(err);
  }
});

module.exports = router;
