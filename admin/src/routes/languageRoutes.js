const express = require('express');
const multer = require('multer');
const router = express.Router();
const apiClient = require('../services/apiClient');
const apiUpload = require('../services/apiUpload');
const { requireAuth } = require('../middleware/requireAuth');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 800 * 1024 * 1024 } });

// Địa chỉ gốc backend (bỏ hậu tố /api) để ghép thành link tải file model đầy đủ
const backendOrigin = (process.env.BACKEND_API_URL || '').replace(/\/api\/?$/, '');

router.use(requireAuth);

// Danh sách ngôn ngữ + model (Vosk/ML Kit) nhóm theo từng ngôn ngữ
router.get('/languages', async (req, res, next) => {
  try {
    const client = apiClient(req);
    const [languagesRes, modelsRes] = await Promise.all([
      client.get('/languages', { params: { all: true } }),
      client.get('/models', { params: { all: true } }),
    ]);

    // Nhóm model theo languageCode để hiển thị ngay dưới từng ngôn ngữ
    const modelsByLanguage = {};
    modelsRes.data.forEach((m) => {
      if (!modelsByLanguage[m.languageCode]) modelsByLanguage[m.languageCode] = [];
      modelsByLanguage[m.languageCode].push(m);
    });

    res.render('languages/list', { items: languagesRes.data, modelsByLanguage, backendOrigin });
  } catch (err) {
    next(err);
  }
});

// Thêm ngôn ngữ mới
router.post('/languages', async (req, res, next) => {
  try {
    const { code, name } = req.body;
    await apiClient(req).post('/languages', { code, name });
    res.redirect('/languages');
  } catch (err) {
    next(err);
  }
});

// Sửa ngôn ngữ (bật/tắt, đổi tên)
router.post('/languages/:id/update', async (req, res, next) => {
  try {
    const { code, name, isActive } = req.body;
    await apiClient(req).put(`/languages/${req.params.id}`, { code, name, isActive: isActive === 'true' });
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

// ===== Quản lý model Vosk/ML Kit ngay trong trang Ngôn ngữ =====

// Thêm model mới cho 1 ngôn ngữ (kèm file upload tùy chọn, field "modelFile")
router.post('/languages/models', upload.single('modelFile'), async (req, res, next) => {
  try {
    const { type, name, languageCode, identifier, downloadUrl, sizeMB, description } = req.body;
    await apiUpload(
      req,
      'post',
      '/models',
      { type, name, languageCode, identifier, downloadUrl, sizeMB, description },
      req.file
    );
    res.redirect('/languages');
  } catch (err) {
    next(err);
  }
});

// Sửa model (kèm thay file mới nếu có)
router.post('/languages/models/:id/update', upload.single('modelFile'), async (req, res, next) => {
  try {
    const { type, name, languageCode, identifier, downloadUrl, sizeMB, description, isActive } = req.body;
    await apiUpload(
      req,
      'put',
      `/models/${req.params.id}`,
      { type, name, languageCode, identifier, downloadUrl, sizeMB, description, isActive },
      req.file
    );
    res.redirect('/languages');
  } catch (err) {
    next(err);
  }
});

// Xóa model (backend tự xóa luôn file trên đĩa nếu có)
router.post('/languages/models/:id/delete', async (req, res, next) => {
  try {
    await apiClient(req).delete(`/models/${req.params.id}`);
    res.redirect('/languages');
  } catch (err) {
    next(err);
  }
});

module.exports = router;
