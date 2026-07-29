const fs = require('fs');
const path = require('path');
const Model = require('../models/Model');
const { UPLOAD_DIR } = require('../middleware/upload');

const deleteFileIfExists = (fileName) => {
  if (!fileName) return;
  const filePath = path.join(UPLOAD_DIR, fileName);
  fs.unlink(filePath, (err) => {
    if (err && err.code !== 'ENOENT') console.error('Không xóa được file model cũ:', err.message);
  });
};

// @desc    Lấy danh sách model (lọc theo type, languageCode); Mobile dùng để biết model nào khả dụng
// @route   GET /api/models?type=vosk|mlkit&languageCode=en&all=true
const getModels = async (req, res, next) => {
  try {
    const { type, languageCode } = req.query;
    const filter = req.query.all === 'true' ? {} : { isActive: true };
    if (type) filter.type = type;
    if (languageCode) filter.languageCode = languageCode;

    const models = await Model.find(filter).sort({ type: 1, languageCode: 1, name: 1 });
    res.json(models);
  } catch (error) {
    next(error);
  }
};

// @desc    Admin thêm model mới (Vosk hoặc ML Kit), kèm upload file (tùy chọn)
// @route   POST /api/models  (multipart/form-data nếu có file, field tên "modelFile")
const createModel = async (req, res, next) => {
  try {
    const payload = { ...req.body };
    if (req.file) {
      payload.fileName = req.file.filename;
      payload.originalFileName = req.file.originalname;
      payload.sizeMB = Math.round((req.file.size / (1024 * 1024)) * 10) / 10;
    }

    const model = await Model.create(payload);
    res.status(201).json(model);
  } catch (error) {
    if (req.file) deleteFileIfExists(req.file.filename); // dọn file nếu tạo record thất bại
    if (error.code === 11000) {
      return res.status(409).json({ message: 'Model này (cùng loại, ngôn ngữ, identifier) đã tồn tại' });
    }
    next(error);
  }
};

// @desc    Admin sửa model, có thể thay file đã upload
// @route   PUT /api/models/:id
const updateModel = async (req, res, next) => {
  try {
    const existing = await Model.findById(req.params.id);
    if (!existing) return res.status(404).json({ message: 'Không tìm thấy model' });

    const payload = { ...req.body };
    if (req.file) {
      payload.fileName = req.file.filename;
      payload.originalFileName = req.file.originalname;
      payload.sizeMB = Math.round((req.file.size / (1024 * 1024)) * 10) / 10;
    }

    const model = await Model.findByIdAndUpdate(req.params.id, payload, { new: true, runValidators: true });

    // Nếu vừa upload file mới thành công, xóa file cũ (nếu có) để khỏi rác đĩa
    if (req.file && existing.fileName) deleteFileIfExists(existing.fileName);

    res.json(model);
  } catch (error) {
    if (req.file) deleteFileIfExists(req.file.filename);
    if (error.code === 11000) {
      return res.status(409).json({ message: 'Model này (cùng loại, ngôn ngữ, identifier) đã tồn tại' });
    }
    next(error);
  }
};

// @desc    Admin xóa model (kèm xóa file trên server nếu có)
// @route   DELETE /api/models/:id
const deleteModel = async (req, res, next) => {
  try {
    const model = await Model.findByIdAndDelete(req.params.id);
    if (!model) return res.status(404).json({ message: 'Không tìm thấy model' });
    deleteFileIfExists(model.fileName);
    res.json({ message: 'Đã xóa model' });
  } catch (error) {
    next(error);
  }
};

module.exports = { getModels, createModel, updateModel, deleteModel };
