const express = require('express');
const router = express.Router();
const multer = require('multer');
const {
  saveVocabulary,
  getMyVocabulary,
  addToFlashcard,
  removeFromFlashcard,
  deleteVocabulary,
  getSystemVocabulary,
  createSystemVocabulary,
  updateSystemVocabulary,
  deleteSystemVocabulary,
  getSystemCategories,
  importSystemVocabulary,
} = require('../controllers/vocabularyController');
const { protect, adminOnly } = require('../middleware/auth');

// Multer memory storage cho Excel upload (tối đa 5MB)
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowed = [
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', // .xlsx
      'application/vnd.ms-excel', // .xls
    ];
    if (allowed.includes(file.mimetype)) cb(null, true);
    else cb(new Error('Chỉ chấp nhận file Excel (.xlsx, .xls)'));
  },
});

router.use(protect);

// Từ vựng yêu thích của cá nhân (Mobile)
router.post('/', saveVocabulary);
router.get('/', getMyVocabulary);
router.put('/:id/flashcard', addToFlashcard);
router.delete('/:id/flashcard', removeFromFlashcard);
router.delete('/:id', deleteVocabulary);

// Kho từ vựng hệ thống - User xem/tra cứu, Admin CRUD
// PHẢI đặt các route tĩnh (/system/categories, /system/import) TRƯỚC /system/:id
router.get('/system/categories', getSystemCategories);
router.post('/system/import', adminOnly, upload.single('file'), importSystemVocabulary);
router.get('/system', getSystemVocabulary);
router.post('/system', adminOnly, createSystemVocabulary);
router.put('/system/:id', adminOnly, updateSystemVocabulary);
router.delete('/system/:id', adminOnly, deleteSystemVocabulary);

module.exports = router;
