const User = require('../models/User');

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

// @desc    Xóa tài khoản
// @route   DELETE /api/users/:id
const deleteUser = async (req, res, next) => {
  try {
    const user = await User.findByIdAndDelete(req.params.id);
    if (!user) return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    res.json({ message: 'Đã xóa tài khoản' });
  } catch (error) {
    next(error);
  }
};

module.exports = { getUsers, getUserById, createUser, updateUser, deleteUser };
