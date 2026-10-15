const mongoose = require('mongoose');
const User = require('../models/User');
const Vocabulary = require('../models/Vocabulary');
const TranslationHistory = require('../models/TranslationHistory');
const AIConversation = require('../models/AIConversation');

// @desc    Lấy danh sách người dùng (có tìm kiếm, phân trang)
// @route   GET /api/users?page=1&limit=20&search=abc
const getUsers = async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const search = req.query.search || '';

    const filter = search
      ? { $or: [{ fullName: new RegExp(search, 'i') }, { email: new RegExp(search, 'i') }] }
      : {};

    const [users, total] = await Promise.all([
      User.find(filter)
        .select('-password')
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit),
      User.countDocuments(filter),
    ]);

    res.json({ users, total, page, totalPages: Math.ceil(total / limit) });
  } catch (error) {
    next(error);
  }
};

// @desc    Lấy chi tiết 1 người dùng
// @route   GET /api/users/:id
const getUserById = async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id).select('-password');
    if (!user) return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    res.json(user);
  } catch (error) {
    next(error);
  }
};

// @desc    Admin tạo tài khoản mới (vd: tạo thêm admin)
// @route   POST /api/users
const createUser = async (req, res, next) => {
  try {
    const { fullName, email, password, role } = req.body;
    const existingUser = await User.findOne({ email });
    if (existingUser) return res.status(409).json({ message: 'Email đã được sử dụng' });

    const user = await User.create({ fullName, email, password, role: role || 'user' });
    res.status(201).json({ id: user._id, fullName: user.fullName, email: user.email, role: user.role });
  } catch (error) {
    next(error);
  }
};

// @desc    Cập nhật thông tin / khóa-mở khóa tài khoản
// @route   PUT /api/users/:id
const updateUser = async (req, res, next) => {
  try {
    const { fullName, role, isActive } = req.body;
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ message: 'Không tìm thấy người dùng' });

    if (fullName !== undefined) user.fullName = fullName;
    if (role !== undefined) user.role = role;
    if (isActive !== undefined) user.isActive = isActive;

    await user.save();
    res.json({ message: 'Cập nhật thành công', user: { id: user._id, fullName: user.fullName, role: user.role, isActive: user.isActive } });
  } catch (error) {
    next(error);
  }
};

// @desc    Xóa tài khoản + CASCADE toàn bộ dữ liệu của user đó
// @route   DELETE /api/users/:id
// MongoDB không có ON DELETE CASCADE như SQL — nếu chỉ xóa document user thì
// vocabularies / translationhistories / aiconversations của user thành dữ liệu
// mồ côi (ref ObjectId trỏ vào _id không còn tồn tại). Vì vậy phải tự cascade,
// và bọc trong TRANSACTION đa document để "xóa hết hoặc không xóa gì":
// nếu chết giữa chừng thì không có trạng thái nửa vời.
// Transaction cần replica set; nếu Mongo đang chạy standalone (docker mặc định)
// thì degrade về xóa tuần tự — dữ liệu vẫn sạch, chỉ mất tính nguyên tử.
const deleteUser = async (req, res, next) => {
  try {
    const userId = req.params.id;
    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ message: 'Không tìm thấy người dùng' });

    const cascade = async (session) => {
      const opts = session ? { session } : {};
      const [vocab, history, conversations] = await Promise.all([
        Vocabulary.deleteMany({ user: userId }, opts),
        TranslationHistory.deleteMany({ user: userId }, opts),
        AIConversation.deleteMany({ user: userId }, opts),
      ]);
      await User.deleteOne({ _id: userId }, opts);
      return {
        vocabularies: vocab.deletedCount,
        histories: history.deletedCount,
        conversations: conversations.deletedCount,
      };
    };

    let deleted;
    let atomic = true;
    const session = await mongoose.startSession();
    try {
      await session.withTransaction(async () => {
        deleted = await cascade(session);
      });
    } catch (err) {
      // Mã 20 / IllegalOperation = standalone không hỗ trợ transaction -> chạy thường
      if (err.code === 20 || /replica set|Transaction numbers/i.test(err.message)) {
        atomic = false;
        deleted = await cascade(null);
      } else {
        throw err;
      }
    } finally {
      session.endSession();
    }

    res.json({ message: 'Đã xóa tài khoản', deleted, atomic });
  } catch (error) {
    next(error);
  }
};

module.exports = { getUsers, getUserById, createUser, updateUser, deleteUser };
