const express = require('express');
const router = express.Router();
const apiClient = require('../services/apiClient');

// Trang đăng nhập
router.get('/login', (req, res) => {
  if (req.session?.token) return res.redirect('/dashboard');
  res.render('login', { error: null });
});

// Xử lý đăng nhập - gọi POST /api/auth/login, chỉ chấp nhận role admin
router.post('/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const { data } = await apiClient(req).post('/auth/login', { email, password });

    if (data.user.role !== 'admin') {
      return res.render('login', { error: 'Tài khoản này không có quyền truy cập trang quản trị' });
    }

    req.session.token = data.token;
    req.session.admin = data.user;
    res.redirect('/dashboard');
  } catch (err) {
    const message = err.response?.data?.message || 'Đăng nhập thất bại, vui lòng thử lại';
    res.render('login', { error: message });
  }
});

// Đăng xuất
router.post('/logout', async (req, res) => {
  try {
    if (req.session?.token) {
      await apiClient(req).post('/auth/logout');
    }
  } catch (e) {
    // bỏ qua lỗi, vẫn hủy session phía admin
  } finally {
    req.session.destroy(() => res.redirect('/login'));
  }
});

module.exports = router;
