// Xử lý route không tồn tại
const notFound = (req, res, next) => {
  res.status(404).json({ message: `Không tìm thấy route: ${req.originalUrl}` });
};

// Xử lý lỗi chung
const errorHandler = (err, req, res, next) => {
  const statusCode = res.statusCode && res.statusCode !== 200 ? res.statusCode : 500;
  console.error(err);
  res.status(statusCode).json({
    message: err.message || 'Lỗi máy chủ nội bộ',
    stack: process.env.NODE_ENV === 'production' ? undefined : err.stack,
  });
};

module.exports = { notFound, errorHandler };
