// Script tạo tài khoản admin đầu tiên cho hệ thống.
// Chạy: node seed/createAdmin.js
require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../src/models/User');

const ADMIN_EMAIL = process.env.SEED_ADMIN_EMAIL || 'admin@example.com';
const ADMIN_PASSWORD = process.env.SEED_ADMIN_PASSWORD || 'Admin@123';
const ADMIN_NAME = process.env.SEED_ADMIN_NAME || 'System Admin';

(async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅ Đã kết nối MongoDB');

    const existing = await User.findOne({ email: ADMIN_EMAIL });
    if (existing) {
      console.log(`⚠️  Tài khoản admin với email "${ADMIN_EMAIL}" đã tồn tại. Bỏ qua.`);
    } else {
      const admin = await User.create({
        fullName: ADMIN_NAME,
        email: ADMIN_EMAIL,
        password: ADMIN_PASSWORD,
        role: 'admin',
      });
      console.log('🎉 Đã tạo tài khoản admin:');
      console.log(`   Email:    ${admin.email}`);
      console.log(`   Password: ${ADMIN_PASSWORD}`);
      console.log('   👉 Hãy đổi mật khẩu này ngay sau lần đăng nhập đầu tiên!');
    }
  } catch (error) {
    console.error('❌ Lỗi khi tạo admin:', error.message);
  } finally {
    await mongoose.disconnect();
    process.exit(0);
  }
})();
