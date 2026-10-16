// Hàm dùng chung cho các script seed: xóa sạch dữ liệu + tạo admin.
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const User = require('../src/models/User');
const Language = require('../src/models/Language');
const Vocabulary = require('../src/models/Vocabulary');
const SystemVocabulary = require('../src/models/SystemVocabulary');
const TranslationHistory = require('../src/models/TranslationHistory');
const AIConversation = require('../src/models/AIConversation');
const Model = require('../src/models/Model');

const UPLOAD_DIR = path.join(__dirname, '..', 'uploads', 'models');

// Collection nghiệp vụ sẽ bị xóa sạch. KHÔNG gồm `settings` (Gemini API key do admin
// nhập) — để mỗi lần seed lại không phải nhập key. Muốn xóa luôn: npm run seed:reset -- --with-settings
const COLLECTIONS = [User, Language, Vocabulary, SystemVocabulary, TranslationHistory, AIConversation, Model];

// Chặn chạy nhầm trên DB production
const assertSafe = () => {
  if (process.env.NODE_ENV === 'production' && !process.argv.includes('--force')) {
    console.error('⛔ NODE_ENV=production: từ chối xóa dữ liệu. Thêm --force nếu bạn chắc chắn.');
    process.exit(1);
  }
};

// Xóa toàn bộ dữ liệu (giữ nguyên collection, index và validator $jsonSchema)
// + dọn file model đã upload trên đĩa (vì record trong DB đã mất, file sẽ thành rác).
async function resetDatabase({ withSettings = process.argv.includes('--with-settings') } = {}) {
  assertSafe();
  console.log(`🧹 Xóa toàn bộ dữ liệu trong DB "${mongoose.connection.name}" ...`);

  const models = [...COLLECTIONS];
  if (withSettings) models.push(require('../src/models/Setting'));

  for (const m of models) {
    const { deletedCount } = await m.deleteMany({});
    console.log(`   - ${m.collection.name}: đã xóa ${deletedCount}`);
  }

  if (fs.existsSync(UPLOAD_DIR)) {
    for (const entry of fs.readdirSync(UPLOAD_DIR)) {
      fs.rmSync(path.join(UPLOAD_DIR, entry), { recursive: true, force: true });
    }
    console.log('   - uploads/models: đã dọn file model');
  }
  if (!withSettings) console.log('   (giữ lại collection settings — Gemini API key không bị mất)');
}

// Tạo tài khoản admin (bỏ qua nếu đã có). Trả về document admin.
async function ensureAdmin() {
  const email = process.env.SEED_ADMIN_EMAIL || 'admin@example.com';
  const password = process.env.SEED_ADMIN_PASSWORD || 'Admin@123';
  const fullName = process.env.SEED_ADMIN_NAME || 'System Admin';

  let admin = await User.findOne({ email });
  if (admin) {
    console.log(`⚠️  Tài khoản admin "${email}" đã tồn tại. Bỏ qua.`);
    return admin;
  }
  admin = await User.create({ fullName, email, password, role: 'admin' });
  console.log(`🎉 Đã tạo tài khoản admin: ${email} / ${password}`);
  console.log('   👉 Hãy đổi mật khẩu này ngay sau lần đăng nhập đầu tiên (Web Admin → Cài đặt)!');
  return admin;
}

module.exports = { resetDatabase, ensureAdmin };
