// Xóa sạch toàn bộ dữ liệu rồi tạo lại tài khoản admin.
// Chạy: npm run seed:reset            (giữ lại Gemini API key trong settings)
//       npm run seed:reset -- --with-settings   (xóa luôn cả settings)
require('dotenv').config();
const mongoose = require('mongoose');
const { resetDatabase, ensureAdmin } = require('./helpers');

(async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅ Đã kết nối MongoDB');
    await resetDatabase();
    await ensureAdmin();
  } catch (error) {
    console.error('❌ Lỗi khi reset DB:', error.message);
    process.exitCode = 1;
  } finally {
    await mongoose.disconnect();
    process.exit();
  }
})();
