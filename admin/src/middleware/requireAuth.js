// Chặn truy cập nếu chưa đăng nhập, đẩy về trang login
const requireAuth = (req, res, next) => {
  if (!req.session?.token) {
    return res.redirect('/login');
  }
  next();
};

module.exports = { requireAuth };
