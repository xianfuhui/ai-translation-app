const express = require('express');
const router = express.Router();
const { getGemini, updateGemini, resetGemini, testGemini } = require('../controllers/settingsController');
const { protect, adminOnly } = require('../middleware/auth');

router.use(protect, adminOnly);

router.get('/gemini', getGemini);
router.put('/gemini', updateGemini);
router.delete('/gemini', resetGemini);
router.post('/gemini/test', testGemini);

module.exports = router;
