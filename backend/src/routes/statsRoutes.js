const express = require('express');
const router = express.Router();
const { getUserStats, getVocabularyStats } = require('../controllers/statsController');
const { protect, adminOnly } = require('../middleware/auth');

router.use(protect, adminOnly);

router.get('/users', getUserStats);
router.get('/vocabulary', getVocabularyStats);

module.exports = router;
