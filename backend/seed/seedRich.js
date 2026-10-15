// Bơm dữ liệu KHỐI LƯỢNG LỚN để DB "ra dáng app đang chạy thật".
// Chạy SAU seed:data:  npm run seed:rich   (idempotent — chạy lại sẽ xóa lô cũ tạo lô mới)
//
// Tạo thêm gì:
// - 2 ngôn ngữ (zh, fr) + 2 model ML Kit tương ứng
// - 32 từ vựng hệ thống theo 4 chủ đề
// - 15 học viên (learner1..15@example.com / User@123), ngày tạo trải 60 ngày,
//   vài tài khoản bị khóa — cho biểu đồ đăng ký & thống kê admin có hình dạng
// - ~250 từ vựng cá nhân, ~2.500 bản ghi lịch sử trải 120 ngày (đủ 4 type,
//   phiên conversation có 2-6 lượt nói), ~30 hội thoại AI
// - user1 được cộng thêm 30 lịch sử + 15 từ để demo trên app nhìn "đã xài lâu"
//
// Kỹ thuật: random có SEED cố định (LCG) — chạy lại ra đúng bộ dữ liệu cũ nên
// việc dọn theo marker luôn khớp; insertMany theo lô; KHÔNG đụng tài khoản seed cũ.
require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('../src/models/User');
const Language = require('../src/models/Language');
const Vocabulary = require('../src/models/Vocabulary');
const SystemVocabulary = require('../src/models/SystemVocabulary');
const TranslationHistory = require('../src/models/TranslationHistory');
const AIConversation = require('../src/models/AIConversation');
const Model = require('../src/models/Model');

// ===== random có seed — tái lập được =====
let _seed = 20260912;
const rnd = () => ((_seed = (_seed * 1103515245 + 12345) % 2147483648) / 2147483648);
const rint = (min, max) => min + Math.floor(rnd() * (max - min + 1));
const pick = (arr) => arr[Math.floor(rnd() * arr.length)];
const daysAgo = (d, jitterMin = 0) =>
  new Date(Date.now() - d * 86400000 - jitterMin * 60000);

const LEARNER_EMAILS = Array.from({ length: 15 }, (_, i) => `learner${i + 1}@example.com`);
const LEARNER_NAMES = [
  'Phạm Minh Châu', 'Lê Quốc Bảo', 'Vũ Thu Hà', 'Đặng Gia Huy', 'Bùi Ngọc Lan',
  'Hồ Thanh Sơn', 'Đỗ Mai Phương', 'Ngô Đức Thịnh', 'Trịnh Khánh Vy', 'Lý Hoàng Nam',
  'Phan Bích Ngọc', 'Dương Tuấn Kiệt', 'Mai Thùy Dung', 'Tạ Quang Minh', 'Chu Diễm Quỳnh',
];

// ===== kho câu (EN->VI là chính, kèm EN->JA và VI->EN) =====
const SENT_EN_VI = [
  ['Could you recommend a good local restaurant?', 'Bạn có thể giới thiệu một nhà hàng địa phương ngon không?'],
  ['I would like to book a room for two nights.', 'Tôi muốn đặt một phòng trong hai đêm.'],
  ['How much does this ticket cost?', 'Vé này giá bao nhiêu?'],
  ['The meeting has been postponed to next Monday.', 'Cuộc họp đã bị hoãn sang thứ Hai tuần sau.'],
  ['Please send me the report by end of day.', 'Vui lòng gửi báo cáo cho tôi trước cuối ngày.'],
  ['Where can I catch the bus to the city center?', 'Tôi có thể bắt xe buýt vào trung tâm ở đâu?'],
  ['I am allergic to peanuts.', 'Tôi bị dị ứng với đậu phộng.'],
  ['Can you speak more slowly, please?', 'Bạn có thể nói chậm lại được không?'],
  ['What time does the museum open?', 'Bảo tàng mở cửa lúc mấy giờ?'],
  ['I have been learning Vietnamese for three months.', 'Tôi đã học tiếng Việt được ba tháng.'],
  ['The weather forecast says it will rain tomorrow.', 'Dự báo thời tiết nói ngày mai trời sẽ mưa.'],
  ['Could you help me carry this luggage?', 'Bạn có thể giúp tôi xách hành lý này không?'],
  ['My flight was delayed by two hours.', 'Chuyến bay của tôi bị trễ hai tiếng.'],
  ['This dish is too spicy for me.', 'Món này quá cay với tôi.'],
  ['I need to exchange some money.', 'Tôi cần đổi một ít tiền.'],
  ['Let me check my calendar first.', 'Để tôi kiểm tra lịch của mình trước đã.'],
];
const SENT_EN_JA = [
  ['Nice to meet you, I look forward to working together.', 'はじめまして、これからよろしくお願いします。'],
  ['Could you say that one more time?', 'もう一度言っていただけますか。'],
  ['I will arrive at the station at nine.', '九時に駅に着きます。'],
  ['This is my first time visiting Tokyo.', '東京を訪れるのは初めてです。'],
];
const SENT_VI_EN = [
  ['Cuối tuần này bạn có rảnh không?', 'Are you free this weekend?'],
  ['Tôi đang trên đường đến văn phòng.', 'I am on my way to the office.'],
  ['Dự án này cần thêm hai người nữa.', 'This project needs two more people.'],
];

// ===== kho từ (đủ rộng để mỗi user bốc không trùng) =====
const WORDS = [
  ['ability', 'khả năng'], ['achieve', 'đạt được'], ['advice', 'lời khuyên'], ['ancient', 'cổ xưa'],
  ['arrive', 'đến nơi'], ['borrow', 'mượn'], ['bravery', 'lòng dũng cảm'], ['calendar', 'lịch'],
  ['celebrate', 'ăn mừng'], ['choice', 'lựa chọn'], ['climate', 'khí hậu'], ['comfort', 'sự thoải mái'],
  ['courage', 'can đảm'], ['curious', 'tò mò'], ['decision', 'quyết định'], ['delicious', 'ngon'],
  ['discover', 'khám phá'], ['distance', 'khoảng cách'], ['effort', 'nỗ lực'], ['emotion', 'cảm xúc'],
  ['engineer', 'kỹ sư'], ['environment', 'môi trường'], ['exchange', 'trao đổi'], ['familiar', 'quen thuộc'],
  ['freedom', 'tự do'], ['friendly', 'thân thiện'], ['generous', 'hào phóng'], ['grateful', 'biết ơn'],
  ['harvest', 'thu hoạch'], ['holiday', 'kỳ nghỉ'], ['honest', 'trung thực'], ['imagine', 'tưởng tượng'],
  ['improve', 'cải thiện'], ['journey', 'hành trình'], ['kindness', 'lòng tốt'], ['language', 'ngôn ngữ'],
  ['lecture', 'bài giảng'], ['library', 'thư viện'], ['luggage', 'hành lý'], ['medicine', 'thuốc'],
  ['memory', 'ký ức'], ['mountain', 'ngọn núi'], ['neighbor', 'hàng xóm'], ['opinion', 'ý kiến'],
  ['patient', 'kiên nhẫn'], ['peaceful', 'yên bình'], ['practice', 'luyện tập'], ['promise', 'lời hứa'],
  ['quality', 'chất lượng'], ['receipt', 'hóa đơn'], ['schedule', 'lịch trình'], ['science', 'khoa học'],
  ['seaside', 'bờ biển'], ['strength', 'sức mạnh'], ['success', 'thành công'], ['sunrise', 'bình minh'],
  ['teacher', 'giáo viên'], ['tradition', 'truyền thống'], ['vacation', 'kỳ nghỉ dài'], ['weather', 'thời tiết'],
];

const SYSTEM_WORDS_RICH = [
  // du lịch
  ['reservation', 'đặt chỗ', '/ˌrezərˈveɪʃn/', 'du lịch'], ['souvenir', 'quà lưu niệm', '/ˌsuːvəˈnɪr/', 'du lịch'],
  ['itinerary', 'lịch trình chuyến đi', '/aɪˈtɪnəreri/', 'du lịch'], ['currency', 'tiền tệ', '/ˈkɜːrənsi/', 'du lịch'],
  ['departure', 'khởi hành', '/dɪˈpɑːrtʃər/', 'du lịch'], ['sightseeing', 'tham quan', '/ˈsaɪtsiːɪŋ/', 'du lịch'],
  ['customs', 'hải quan', '/ˈkʌstəmz/', 'du lịch'], ['boarding pass', 'thẻ lên máy bay', null, 'du lịch'],
  // công việc
  ['negotiation', 'đàm phán', '/nɪˌɡoʊʃiˈeɪʃn/', 'công việc'], ['colleague', 'đồng nghiệp', '/ˈkɑːliːɡ/', 'công việc'],
  ['presentation', 'bài thuyết trình', '/ˌpriːzenˈteɪʃn/', 'công việc'], ['agenda', 'chương trình họp', '/əˈdʒendə/', 'công việc'],
  ['feedback', 'phản hồi', '/ˈfiːdbæk/', 'công việc'], ['contract', 'hợp đồng', '/ˈkɑːntrækt/', 'công việc'],
  ['promotion', 'thăng chức', '/prəˈmoʊʃn/', 'công việc'], ['overtime', 'tăng ca', '/ˈoʊvərtaɪm/', 'công việc'],
  // giao tiếp
  ['appreciate', 'trân trọng', '/əˈpriːʃieɪt/', 'giao tiếp'], ['apologize', 'xin lỗi', '/əˈpɑːlədʒaɪz/', 'giao tiếp'],
  ['congratulations', 'chúc mừng', '/kənˌɡrætʃəˈleɪʃnz/', 'giao tiếp'], ['excuse me', 'xin phép / cho hỏi', null, 'giao tiếp'],
  ['pleasure', 'hân hạnh', '/ˈpleʒər/', 'giao tiếp'], ['introduce', 'giới thiệu', '/ˌɪntrəˈduːs/', 'giao tiếp'],
  ['invitation', 'lời mời', '/ˌɪnvɪˈteɪʃn/', 'giao tiếp'], ['farewell', 'tạm biệt', '/ˌferˈwel/', 'giao tiếp'],
  // học tập
  ['assignment', 'bài tập', '/əˈsaɪnmənt/', 'học tập'], ['deadline', 'hạn nộp', '/ˈdedlaɪn/', 'học tập'],
  ['knowledge', 'kiến thức', '/ˈnɑːlɪdʒ/', 'học tập'], ['scholarship', 'học bổng', '/ˈskɑːlərʃɪp/', 'học tập'],
  ['semester', 'học kỳ', '/sɪˈmestər/', 'học tập'], ['graduate', 'tốt nghiệp', '/ˈɡrædʒueɪt/', 'học tập'],
  ['research', 'nghiên cứu', '/rɪˈsɜːrtʃ/', 'học tập'], ['certificate', 'chứng chỉ', '/sərˈtɪfɪkət/', 'học tập'],
];

const AI_TOPICS = [
  ['Luyện phỏng vấn xin việc', 'Hãy đóng vai nhà tuyển dụng, phỏng vấn tôi bằng tiếng Anh nhé.', 'Great! Let us start. Tell me a little bit about yourself.'],
  ['Sửa ngữ pháp đoạn văn', 'Fix this paragraph: I goes to school every day and study English very hardly.', 'Here is the corrected version: "I go to school every day and study English very hard."'],
  ['Hỏi về thì hiện tại hoàn thành', 'Khi nào dùng thì hiện tại hoàn thành vậy?', 'Thì hiện tại hoàn thành dùng khi hành động xảy ra trong quá khứ nhưng còn liên quan đến hiện tại.'],
  ['Luyện hội thoại đặt phòng', 'Role-play a hotel check-in conversation with me.', 'Welcome to our hotel! Do you have a reservation with us tonight?'],
  ['Từ vựng chủ đề công sở', 'Cho tôi 5 từ vựng tiếng Anh hay dùng trong cuộc họp.', 'Sure! agenda, minutes, action item, follow up, and wrap up. Would you like example sentences?'],
];

async function run() {
  await mongoose.connect(process.env.MONGO_URI, { autoIndex: false });
  console.log('✅ Đã kết nối MongoDB');

  const user1 = await User.findOne({ email: 'user1@example.com' });
  if (!user1) {
    console.error('❌ Chưa có dữ liệu nền — chạy `npm run seed:data` trước rồi hãy chạy seed:rich.');
    process.exit(1);
  }

  // ===== 1. Thêm ngôn ngữ + model ML Kit =====
  const extraLangs = [
    { code: 'zh', name: 'Tiếng Trung', isActive: true },
    { code: 'fr', name: 'Tiếng Pháp', isActive: true },
  ];
  await Language.deleteMany({ code: { $in: extraLangs.map((l) => l.code) } });
  await Language.insertMany(extraLangs);
  const extraModels = [
    { type: 'mlkit', name: 'ML Kit Chinese', languageCode: 'zh', identifier: 'zh', sizeMB: 30, description: 'Tự tải khi cần, ~30MB', isActive: true },
    { type: 'mlkit', name: 'ML Kit French', languageCode: 'fr', identifier: 'fr', sizeMB: 30, description: 'Tự tải khi cần, ~30MB', isActive: true },
  ];
  await Model.deleteMany({ type: 'mlkit', identifier: { $in: ['zh', 'fr'] } });
  await Model.insertMany(extraModels);
  console.log('✅ +2 ngôn ngữ (zh, fr) + 2 model ML Kit');

  // ===== 2. Kho từ hệ thống thêm 32 từ / 4 chủ đề =====
  const admin = await User.findOne({ email: 'admin@example.com' });
  await SystemVocabulary.deleteMany({ word: { $in: SYSTEM_WORDS_RICH.map((w) => w[0]) } });
  await SystemVocabulary.insertMany(
    SYSTEM_WORDS_RICH.map(([word, meaning, phonetic, category]) => ({
      word, meaning, category,
      phonetic: phonetic || undefined,
      sourceLanguage: 'en', targetLanguage: 'vi',
      createdBy: admin?._id ?? null,
    }))
  );
  console.log(`✅ +${SYSTEM_WORDS_RICH.length} từ vựng hệ thống (4 chủ đề)`);

  // ===== 3. 15 học viên, ngày tạo trải 60 ngày =====
  const oldLearners = await User.find({ email: { $in: LEARNER_EMAILS } }).select('_id');
  const oldIds = oldLearners.map((u) => u._id);
  await Promise.all([
    Vocabulary.deleteMany({ user: { $in: oldIds } }),
    TranslationHistory.deleteMany({ user: { $in: oldIds } }),
    AIConversation.deleteMany({ user: { $in: oldIds } }),
    User.deleteMany({ _id: { $in: oldIds } }),
  ]);

  const passwordHash = await bcrypt.hash('User@123', 10); // hash sẵn 1 lần — insertMany không chạy pre-save hook
  const learners = await User.insertMany(
    LEARNER_EMAILS.map((email, i) => {
      const created = daysAgo(rint(3, 60), rint(0, 720));
      return {
        fullName: LEARNER_NAMES[i], email, password: passwordHash, role: 'user',
        isActive: i % 7 !== 6, // ~2 tài khoản bị khóa cho thống kê admin
        createdAt: created, updatedAt: created,
        lastLoginAt: daysAgo(rint(0, 5), rint(0, 720)),
      };
    })
  );
  console.log(`✅ +${learners.length} học viên (learner1..15@example.com / User@123)`);

  // ===== 4. Từ vựng cá nhân (~250) — bốc không trùng theo unique index =====
  const vocabDocs = [];
  const addVocabFor = (uid, count) => {
    const pool = [...WORDS];
    for (let k = 0; k < count && pool.length; k++) {
      const [word, meaning] = pool.splice(Math.floor(rnd() * pool.length), 1)[0];
      const created = daysAgo(rint(0, 90), rint(0, 720));
      vocabDocs.push({
        user: uid, word, meaning, sourceLanguage: 'en', targetLanguage: 'vi',
        source: rnd() < 0.6 ? 'conversation' : 'manual',
        inFlashcard: rnd() < 0.45,
        phonetic: rnd() < 0.5 ? `/ˈ${word.slice(0, 4)}…/` : undefined,
        createdAt: created, updatedAt: created,
      });
    }
  };
  for (const u of learners) addVocabFor(u._id, rint(8, 25));
  // user1: dọn lô cũ theo đúng pool từ rồi thêm 15 từ
  await Vocabulary.deleteMany({ user: user1._id, word: { $in: WORDS.map((w) => w[0]) } });
  addVocabFor(user1._id, 15);
  await Vocabulary.insertMany(vocabDocs);
  console.log(`✅ +${vocabDocs.length} từ vựng cá nhân`);

  // ===== 5. Lịch sử dịch (~2.500) trải 120 ngày, đủ 4 type =====
  const histDocs = [];
  const addHistoryFor = (uid, count) => {
    for (let k = 0; k < count; k++) {
      const created = daysAgo(rint(0, 120), rint(0, 1380));
      const roll = rnd();
      if (roll < 0.7) {
        const [s, t] = pick(SENT_EN_VI);
        histDocs.push({ user: uid, sourceLanguage: 'en', targetLanguage: 'vi', sourceText: s, translatedText: t, type: 'text', createdAt: created, updatedAt: created });
      } else if (roll < 0.82) {
        const [s, t] = pick(SENT_VI_EN);
        histDocs.push({ user: uid, sourceLanguage: 'vi', targetLanguage: 'en', sourceText: s, translatedText: t, type: 'speech', createdAt: created, updatedAt: created });
      } else if (roll < 0.9) {
        const [s, t] = pick(SENT_EN_JA);
        histDocs.push({ user: uid, sourceLanguage: 'en', targetLanguage: 'ja', sourceText: s, translatedText: t, type: 'ai_chat', createdAt: created, updatedAt: created });
      } else {
        const n = rint(2, 6);
        const segments = Array.from({ length: n }, (_, i) => {
          const [s, t] = pick(SENT_EN_VI);
          return { sourceText: s, translatedText: t, at: new Date(created.getTime() + i * rint(8, 30) * 1000) };
        });
        histDocs.push({
          user: uid, sourceLanguage: 'en', targetLanguage: 'vi', type: 'conversation', segments,
          startedAt: segments[0].at, endedAt: segments[n - 1].at,
          summary: rnd() < 0.3 ? `Phiên hội thoại ${n} lượt nói về giao tiếp hằng ngày.` : undefined,
          createdAt: segments[n - 1].at, updatedAt: segments[n - 1].at,
        });
      }
    }
  };
  for (const u of learners) addHistoryFor(u._id, rint(80, 250));
  // user1: dọn lô rich cũ (nhận diện theo pool câu của seedRich) rồi thêm 30
  const richSentences = [...SENT_EN_VI, ...SENT_EN_JA, ...SENT_VI_EN].map((p) => p[0]);
  await TranslationHistory.deleteMany({ user: user1._id, $or: [{ sourceText: { $in: richSentences } }, { 'segments.0.sourceText': { $in: richSentences } }] });
  addHistoryFor(user1._id, 30);
  for (let i = 0; i < histDocs.length; i += 500) {
    await TranslationHistory.insertMany(histDocs.slice(i, i + 500));
  }
  console.log(`✅ +${histDocs.length} bản ghi lịch sử (trải 120 ngày, đủ text/speech/ai_chat/conversation)`);

  // ===== 6. Hội thoại AI (~30) =====
  const convDocs = [];
  for (const u of learners) {
    const n = rint(0, 3);
    for (let k = 0; k < n; k++) {
      const [title, q, a] = pick(AI_TOPICS);
      const created = daysAgo(rint(0, 60), rint(0, 720));
      const turns = rint(1, 4);
      const messages = [];
      for (let t = 0; t < turns; t++) {
        messages.push({ role: 'user', content: t === 0 ? q : 'Cho tôi thêm một ví dụ nữa nhé.', createdAt: created, updatedAt: created });
        messages.push({ role: 'assistant', content: t === 0 ? a : 'Sure! Here is another example for you to practice with.', createdAt: created, updatedAt: created });
      }
      convDocs.push({
        user: u._id, title, messages,
        summary: rnd() < 0.4 ? `Hội thoại luyện tập: ${title.toLowerCase()}.` : undefined,
        createdAt: created, updatedAt: created,
      });
    }
  }
  await AIConversation.insertMany(convDocs);
  console.log(`✅ +${convDocs.length} hội thoại AI`);

  console.log('\n🎉 Enrich xong. Số liệu hiện tại:');
  for (const m of [User, Language, Model, Vocabulary, SystemVocabulary, TranslationHistory, AIConversation]) {
    console.log(`   ${m.collection.name}: ${await m.estimatedDocumentCount()}`);
  }

  await mongoose.disconnect();
  process.exit(0);
}

run().catch((err) => {
  console.error('❌ Lỗi khi enrich dữ liệu:', err);
  process.exit(1);
});
