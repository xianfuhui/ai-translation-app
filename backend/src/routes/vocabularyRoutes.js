const express = require('express');
const router = express.Router();
const {
  saveVocabulary,
  getMyVocabulary,
  addToFlashcard,
  deleteVocabulary,
  getSystemVocabulary,
  createSystemVocabulary,
  updateSystemVocabulary,
  deleteSystemVocabulary,
} = require('../controllers/vocabularyController');
const { protect, adminOnly } = require('../middleware/auth');

router.use(protect);

// Từ vựng yêu thích của cá nhân (Mobile)
router.post('/', saveVocabulary);
router.get('/', getMyVocabulary);
router.put('/:id/flashcard', addToFlashcard);
router.delete('/:id', deleteVocabulary);

// Kho từ vựng hệ thống - User xem/tra cứu, Admin CRUD
router.get('/system', getSystemVocabulary);
router.post('/system', adminOnly, createSystemVocabulary);
router.put('/system/:id', adminOnly, updateSystemVocabulary);
router.delete('/system/:id', adminOnly, deleteSystemVocabulary);

module.exports = router;
