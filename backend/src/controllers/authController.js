const User = require('../models/User');
const generateToken = require('../utils/generateToken');

// @desc    Đăng ký tài khoản (chỉ Mobile - role mặc định "user")
// @route   POST /api/auth/register
const register = async (req, res, next) => {
  try {
    const { fullName, email, password } = req.body;

    if (!fullName || !email || !password) {
      return res.status(400).json({ message: 'Vui lòng nhập đầy đủ họ tên, email và mật khẩu' });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(409).json({ message: 'Email đã được sử dụng' });
    }

    const user = await User.create({ fullName, email, password, role: 'user' });

    res.status(201).json({
      message: 'Đăng ký thành công',
      user: { id: user._id, fullName: user.fullName, email: user.email, role: user.role },
      token: generateToken(user._id),
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Đăng nhập (dùng chung cho Mobile user và Web admin)
// @route   POST /api/auth/login
const login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email }).select('+password');
    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ message: 'Email hoặc mật khẩu không đúng' });
    }

    if (!user.isActive) {
      return res.status(403).json({ message: 'Tài khoản đã bị khóa' });
    }

    user.lastLoginAt = new Date();
    await user.save();

    res.json({
      message: 'Đăng nhập thành công',
      user: { id: user._id, fullName: user.fullName, email: user.email, role: user.role },
      token: generateToken(user._id),
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Đăng xuất
// @route   POST /api/auth/logout
// Lưu ý: với JWT stateless, đăng xuất thực chất được xử lý ở client (xóa token).
// Endpoint này hữu ích nếu về sau cần blacklist token hoặc ghi log.
const logout = async (req, res, next) => {
  try {
    res.json({ message: 'Đăng xuất thành công' });
  } catch (error) {
    next(error);
  }
};

// @desc    Đổi mật khẩu
// @route   PUT /api/auth/change-password
const changePassword = async (req, res, next) => {
  try {
    const { oldPassword, newPassword } = req.body;

    if (!oldPassword || !newPassword) {
      return res.status(400).json({ message: 'Vui lòng nhập mật khẩu cũ và mật khẩu mới' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ message: 'Mật khẩu mới phải có ít nhất 6 ký tự' });
    }

    const user = await User.findById(req.user._id).select('+password');
    if (!(await user.comparePassword(oldPassword))) {
      return res.status(401).json({ message: 'Mật khẩu cũ không đúng' });
    }

    user.password = newPassword;
    await user.save();

    res.json({ message: 'Đổi mật khẩu thành công' });
  } catch (error) {
    next(error);
  }
};

// @desc    Lấy thông tin tài khoản đang đăng nhập
// @route   GET /api/auth/me
const getMe = async (req, res, next) => {
  try {
    res.json({
      id: req.user._id,
      fullName: req.user.fullName,
      email: req.user.email,
      role: req.user.role,
    });
  } catch (error) {
    next(error);
  }
};

module.exports = { register, login, logout, changePassword, getMe };
