const express = require('express');
const router = express.Router();
const { getModels, createModel, updateModel, deleteModel } = require('../controllers/modelController');
const { protect, adminOnly } = require('../middleware/auth');
const { uploadModelFile } = require('../middleware/upload');

router.get('/', protect, getModels); // Mobile: lấy danh sách model khả dụng theo ngôn ngữ

// Field file trong form-data phải tên là "modelFile"
router.post('/', protect, adminOnly, uploadModelFile.single('modelFile'), createModel);
router.put('/:id', protect, adminOnly, uploadModelFile.single('modelFile'), updateModel);
router.delete('/:id', protect, adminOnly, deleteModel);

module.exports = router;
