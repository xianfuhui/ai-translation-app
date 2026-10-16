// Script tạo tài khoản admin đầu tiên cho hệ thống (bỏ qua nếu đã tồn tại).
// Chạy: node seed/createAdmin.js
require('dotenv').config();
const mongoose = require('mongoose');
const { ensureAdmin } = require('./helpers');

(async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅ Đã kết nối MongoDB');
    await ensureAdmin();
  } catch (error) {
    console.error('❌ Lỗi khi tạo admin:', error.message);
  } finally {
    await mongoose.disconnect();
    process.exit(0);
  }
})();
