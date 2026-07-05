const express = require('express');
const router = express.Router();
const { getLanguages, createLanguage, updateLanguage, deleteLanguage } = require('../controllers/languageController');
const { protect, adminOnly } = require('../middleware/auth');

router.get('/', protect, getLanguages); // Mobile: chọn ngôn ngữ dịch

router.post('/', protect, adminOnly, createLanguage);
router.put('/:id', protect, adminOnly, updateLanguage);
router.delete('/:id', protect, adminOnly, deleteLanguage);

module.exports = router;
