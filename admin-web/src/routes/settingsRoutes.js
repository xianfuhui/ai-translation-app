const express = require('express');
const router = express.Router();
const apiClient = require('../services/apiClient');
const { requireAuth } = require('../middleware/requireAuth');

router.use(requireAuth);

// Lưu thông báo 1 lần (flash) vào session rồi redirect về /settings
const flash = (req, type, text, section) => {
  req.session.flash = { type, text, section };
};

const errMsg = (err, fallback) => err.response?.data?.message || fallback;

// Trang cài đặt: Gemini API + đổi mật khẩu
router.get('/settings', async (req, res, next) => {
  try {
    const { data: gemini } = await apiClient(req).get('/settings/gemini');
    const message = req.session.flash || null;
    delete req.session.flash;
    res.render('settings', { gemini, message });
  } catch (err) {
    next(err);
  }
});

// Lưu Gemini API key / model do admin nhập
router.post('/settings/gemini', async (req, res) => {
  const { apiKey, model } = req.body;
  try {
    const { data } = await apiClient(req).put('/settings/gemini', { apiKey, model });
    flash(req, 'success', data.message, 'gemini');
  } catch (err) {
    flash(req, 'error', errMsg(err, 'Không lưu được cấu hình Gemini'), 'gemini');
  }
  res.redirect('/settings');
});

// Thử kết nối Gemini (dùng key vừa nhập nếu có, chưa cần lưu)
router.post('/settings/gemini/test', async (req, res) => {
  const { apiKey, model } = req.body;
  try {
    const { data } = await apiClient(req).post('/settings/gemini/test', { apiKey, model });
    flash(req, 'success', data.message, 'gemini');
  } catch (err) {
    flash(req, 'error', errMsg(err, 'Không kiểm tra được kết nối Gemini'), 'gemini');
  }
  res.redirect('/settings');
});

// Xóa key đã nhập -> quay lại dùng .env
router.post('/settings/gemini/reset', async (req, res) => {
  try {
    const { data } = await apiClient(req).delete('/settings/gemini');
    flash(req, 'success', data.message, 'gemini');
  } catch (err) {
    flash(req, 'error', errMsg(err, 'Không xóa được cấu hình'), 'gemini');
  }
  res.redirect('/settings');
});

// Đổi mật khẩu admin đang đăng nhập
router.post('/settings/password', async (req, res) => {
  const { oldPassword, newPassword, confirmPassword } = req.body;

  if (!oldPassword || !newPassword || !confirmPassword) {
    flash(req, 'error', 'Vui lòng nhập đầy đủ các ô mật khẩu', 'password');
  } else if (newPassword.length < 6) {
    flash(req, 'error', 'Mật khẩu mới phải có ít nhất 6 ký tự', 'password');
  } else if (newPassword !== confirmPassword) {
    flash(req, 'error', 'Mật khẩu xác nhận không khớp', 'password');
  } else if (newPassword === oldPassword) {
    flash(req, 'error', 'Mật khẩu mới phải khác mật khẩu hiện tại', 'password');
  } else {
    try {
      // Backend trả 401 khi mật khẩu cũ sai -> bắt tại đây, không để bị coi là hết phiên đăng nhập
      await apiClient(req).put('/auth/change-password', { oldPassword, newPassword });
      flash(req, 'success', 'Đổi mật khẩu thành công', 'password');
    } catch (err) {
      flash(req, 'error', errMsg(err, 'Không đổi được mật khẩu'), 'password');
    }
  }
  res.redirect('/settings');
});

module.exports = router;
