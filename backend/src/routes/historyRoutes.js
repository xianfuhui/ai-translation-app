const express = require('express');
const router = express.Router();
const {
  createHistory,
  getMyHistory,
  deleteMyHistory,
  getAllHistoryAdmin,
  deleteHistoryAdmin,
} = require('../controllers/historyController');
const { protect, adminOnly } = require('../middleware/auth');

router.use(protect);

// Lịch sử cá nhân (Mobile)
router.post('/', createHistory);
router.get('/', getMyHistory);
router.delete('/:id', deleteMyHistory);

// Quản lý lịch sử toàn hệ thống (Web Admin)
router.get('/admin/all', adminOnly, getAllHistoryAdmin);
router.delete('/admin/:id', adminOnly, deleteHistoryAdmin);

module.exports = router;
