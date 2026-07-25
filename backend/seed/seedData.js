// Script tạo dữ liệu mẫu để kiểm thử toàn bộ hệ thống.
// Chạy: node seed/seedData.js
// An toàn chạy nhiều lần - sẽ xóa dữ liệu mẫu cũ (đánh dấu qua email/từ khóa) trước khi tạo lại.
require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../src/models/User');
const Language = require('../src/models/Language');
const Vocabulary = require('../src/models/Vocabulary');
const SystemVocabulary = require('../src/models/SystemVocabulary');
const TranslationHistory = require('../src/models/TranslationHistory');
const AIConversation = require('../src/models/AIConversation');

const DEMO_USER_EMAILS = ['user1@example.com', 'user2@example.com'];

async function run() {
  await mongoose.connect(process.env.MONGO_URI);
  console.log('✅ Đã kết nối MongoDB');

  // ===== 1. Ngôn ngữ hỗ trợ =====
  const languageData = [
    { code: 'en', name: 'Tiếng Anh', translationModel: 'opus-mt-en-vi', voskModelName: 'vosk-model-small-en-us-0.15', isActive: true },
    { code: 'vi', name: 'Tiếng Việt', translationModel: 'opus-mt-vi-en', voskModelName: 'vosk-model-vn-0.4', isActive: true },
    { code: 'ja', name: 'Tiếng Nhật', translationModel: 'opus-mt-ja-vi', voskModelName: 'vosk-model-small-ja-0.22', isActive: true },
    { code: 'ko', name: 'Tiếng Hàn', translationModel: 'opus-mt-ko-vi', voskModelName: 'vosk-model-small-ko-0.22', isActive: false },
  ];
  await Language.deleteMany({ code: { $in: languageData.map((l) => l.code) } });
  const languages = await Language.insertMany(languageData);
  console.log(`✅ Đã tạo ${languages.length} ngôn ngữ`);
  const [en, vi, ja] = languages;

  // ===== 2. Tài khoản demo (2 user thường) =====
  await User.deleteMany({ email: { $in: DEMO_USER_EMAILS } });
  const users = await User.create([
    { fullName: 'Nguyễn Văn A', email: DEMO_USER_EMAILS[0], password: 'User@123', role: 'user' },
    { fullName: 'Trần Thị B', email: DEMO_USER_EMAILS[1], password: 'User@123', role: 'user' },
  ]);
  console.log(`✅ Đã tạo ${users.length} tài khoản user demo (mật khẩu: User@123)`);
  const [user1, user2] = users;

  // ===== 3. Kho từ vựng hệ thống =====
  const systemWords = [
    { word: 'hello', meaning: 'xin chào', sourceLanguage: 'en', targetLanguage: 'vi', category: 'giao tiếp' },
    { word: 'thank you', meaning: 'cảm ơn', sourceLanguage: 'en', targetLanguage: 'vi', category: 'giao tiếp' },
    { word: 'airport', meaning: 'sân bay', sourceLanguage: 'en', targetLanguage: 'vi', category: 'du lịch' },
    { word: 'passport', meaning: 'hộ chiếu', sourceLanguage: 'en', targetLanguage: 'vi', category: 'du lịch' },
    { word: 'meeting', meaning: 'cuộc họp', sourceLanguage: 'en', targetLanguage: 'vi', category: 'công việc' },
    { word: 'deadline', meaning: 'hạn chót', sourceLanguage: 'en', targetLanguage: 'vi', category: 'công việc' },
    { word: 'ありがとう', meaning: 'cảm ơn', sourceLanguage: 'ja', targetLanguage: 'vi', category: 'giao tiếp' },
    { word: 'こんにちは', meaning: 'xin chào', sourceLanguage: 'ja', targetLanguage: 'vi', category: 'giao tiếp' },
  ];
  await SystemVocabulary.deleteMany({ word: { $in: systemWords.map((w) => w.word) } });
  const systemVocab = await SystemVocabulary.insertMany(
    systemWords.map((w) => ({ ...w, createdBy: null }))
  );
  console.log(`✅ Đã tạo ${systemVocab.length} từ vựng trong kho hệ thống`);

  // ===== 4. Từ vựng yêu thích của user1 =====
  await Vocabulary.deleteMany({ user: user1._id });
  const myVocab = await Vocabulary.insertMany([
    { user: user1._id, word: 'hello', meaning: 'xin chào', sourceLanguage: 'en', targetLanguage: 'vi', source: 'manual', inFlashcard: true },
    { user: user1._id, word: 'beautiful', meaning: 'xinh đẹp', sourceLanguage: 'en', targetLanguage: 'vi', source: 'conversation', inFlashcard: true },
    { user: user1._id, word: 'journey', meaning: 'hành trình', sourceLanguage: 'en', targetLanguage: 'vi', source: 'manual', inFlashcard: false },
  ]);
  console.log(`✅ Đã tạo ${myVocab.length} từ vựng yêu thích cho ${user1.email}`);

  // ===== 5. Lịch sử dịch thuật =====
  await TranslationHistory.deleteMany({ user: { $in: [user1._id, user2._id] } });
  const now = Date.now();
  const history = await TranslationHistory.insertMany([
    {
      user: user1._id,
      sourceLanguage: 'en',
      targetLanguage: 'vi',
      sourceText: 'Where is the nearest airport?',
      translatedText: 'Sân bay gần nhất ở đâu?',
      type: 'text',
      createdAt: new Date(now - 1000 * 60 * 60 * 24 * 1),
    },
    {
      user: user1._id,
      sourceLanguage: 'en',
      targetLanguage: 'vi',
      sourceText: 'I have a meeting tomorrow morning.',
      translatedText: 'Tôi có một cuộc họp vào sáng mai.',
      type: 'speech',
      createdAt: new Date(now - 1000 * 60 * 60 * 24 * 3),
    },
    {
      user: user2._id,
      sourceLanguage: 'ja',
      targetLanguage: 'vi',
      sourceText: 'こんにちは、元気ですか？',
      translatedText: 'Xin chào, bạn khỏe không?',
      type: 'text',
      createdAt: new Date(now - 1000 * 60 * 60 * 24 * 2),
    },
  ]);
  console.log(`✅ Đã tạo ${history.length} bản ghi lịch sử dịch thuật`);

  // ===== 6. Hội thoại AI mẫu =====
  await AIConversation.deleteMany({ user: user1._id });
  const conversation = await AIConversation.create({
    user: user1._id,
    title: 'Luyện tập hội thoại nhà hàng',
    messages: [
      { role: 'user', content: 'Hãy đóng vai nhân viên nhà hàng, tôi muốn gọi món bằng tiếng Anh.' },
      { role: 'assistant', content: 'Sure! Welcome to our restaurant, what would you like to order today?' },
      { role: 'user', content: 'Câu đó nghĩa là gì?' },
      { role: 'assistant', content: 'Câu đó nghĩa là: "Chào mừng đến nhà hàng của chúng tôi, hôm nay bạn muốn gọi món gì?"' },
    ],
    summary: 'Luyện hội thoại gọi món tại nhà hàng bằng tiếng Anh, có giải thích nghĩa câu.',
  });
  console.log(`✅ Đã tạo 1 hội thoại AI mẫu cho ${user1.email}`);

  console.log('\n🎉 Seed dữ liệu mẫu hoàn tất!\n');
  console.log('----- TÀI KHOẢN KIỂM THỬ -----');
  console.log(`User 1: ${DEMO_USER_EMAILS[0]} / User@123`);
  console.log(`User 2: ${DEMO_USER_EMAILS[1]} / User@123`);
  console.log('Admin : chạy "npm run seed:admin" nếu chưa có (admin@example.com / Admin@123)');
  console.log('-------------------------------\n');

  await mongoose.disconnect();
  process.exit(0);
}

run().catch((err) => {
  console.error('❌ Lỗi khi seed dữ liệu:', err);
  process.exit(1);
});
