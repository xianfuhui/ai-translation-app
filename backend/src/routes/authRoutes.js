const express = require('express');
const router = express.Router();
const { register, login, logout, changePassword, getMe } = require('../controllers/authController');
const { protect } = require('../middleware/auth');

router.post('/register', register); // Mobile only
router.post('/login', login); // Mobile + Web Admin
router.post('/logout', protect, logout); // Mobile + Web Admin
router.put('/change-password', protect, changePassword); // Mobile + Web Admin
router.get('/me', protect, getMe);

module.exports = router;
