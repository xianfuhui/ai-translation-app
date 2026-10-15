/**
 * Đồng bộ "hợp đồng dữ liệu" xuống tầng DB — chạy: npm run db:sync
 *
 * Làm 2 việc:
 * 1. Gắn $jsonSchema validator cho cả 7 collections. Mongoose validate ở tầng app,
 *    nhưng ai ghi thẳng vào Mongo (mongosh, script, service khác) là lách được hết —
 *    validator tầng DB chặn nốt đường đó.
 *    - validationLevel 'moderate': chỉ validate document MỚI hoặc document hợp lệ
 *      bị sửa — document cũ lỡ sai không làm app chết.
 *    - validationAction 'error': ghi sai là từ chối thẳng (không chỉ cảnh báo).
 * 2. Model.syncIndexes(): build index khai báo trong Mongoose schema và DROP index
 *    thừa không còn khai báo (vd index đơn `user_1` cũ đã thay bằng compound).
 *
 * Chạy lại bao nhiêu lần cũng được (idempotent).
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');

const User = require('../src/models/User');
const Language = require('../src/models/Language');
const Model = require('../src/models/Model');
const Vocabulary = require('../src/models/Vocabulary');
const SystemVocabulary = require('../src/models/SystemVocabulary');
const TranslationHistory = require('../src/models/TranslationHistory');
const AIConversation = require('../src/models/AIConversation');

// ===== $jsonSchema cho từng collection =====
// Lưu ý: chỉ ràng những field bất biến về nghiệp vụ (required/enum/kiểu/cận),
// KHÔNG bật additionalProperties:false — để schema còn tiến hóa được.

const objectId = { bsonType: 'objectId' };
const str = { bsonType: 'string' };
const bool = { bsonType: 'bool' };
const date = { bsonType: 'date' };

const validators = {
  users: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['fullName', 'email', 'password'],
      properties: {
        fullName: { ...str, minLength: 1 },
        email: { ...str, pattern: '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$' },
        password: { ...str, minLength: 20 }, // luôn là hash bcrypt (60 ký tự), không bao giờ là plaintext ngắn
        role: { enum: ['user', 'admin'] },
        isActive: bool,
        lastLoginAt: { bsonType: ['date', 'null'] },
      },
    },
  },

  languages: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['code', 'name'],
      properties: {
        code: { ...str, pattern: '^[a-z]{2,3}(-[A-Za-z0-9]{2,8})?$' }, // BCP-47 rút gọn: en, vi, ja, zh-CN
        name: { ...str, minLength: 1 },
        isActive: bool,
      },
    },
  },

  models: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['type', 'name', 'languageCode', 'identifier'],
      properties: {
        type: { enum: ['vosk', 'mlkit'] },
        name: { ...str, minLength: 1 },
        languageCode: { ...str, minLength: 2 },
        identifier: { ...str, minLength: 1 },
        sizeMB: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0 },
        isActive: bool,
      },
    },
  },

  vocabularies: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['user', 'word', 'meaning'],
      properties: {
        user: objectId,
        word: { ...str, minLength: 1 },
        meaning: { ...str, minLength: 1 },
        source: { enum: ['conversation', 'manual'] },
        inFlashcard: bool,
      },
    },
  },

  systemvocabularies: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['word', 'meaning'],
      properties: {
        word: { ...str, minLength: 1 },
        meaning: { ...str, minLength: 1 },
        createdBy: { bsonType: ['objectId', 'null'] },
      },
    },
  },

  // Collection đa hình: ràng buộc CÓ ĐIỀU KIỆN theo `type` ngay tại tầng DB —
  // 'conversation' bắt buộc có segments >= 1 lượt; các type còn lại bắt buộc
  // có đủ sourceText + translatedText (đây là điều pre-validate hook của
  // Mongoose đang làm ở tầng app, giờ DB tự bảo vệ được chính nó).
  translationhistories: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['user', 'sourceLanguage', 'targetLanguage', 'type'],
      properties: {
        user: objectId,
        sourceLanguage: { ...str, minLength: 2 },
        targetLanguage: { ...str, minLength: 2 },
        type: { enum: ['text', 'speech', 'ai_chat', 'conversation'] },
        startedAt: { bsonType: ['date', 'null'] },
        endedAt: { bsonType: ['date', 'null'] },
      },
      oneOf: [
        {
          properties: { type: { enum: ['conversation'] } },
          required: ['segments'],
          // segments: mảng lượt nói, mỗi lượt đủ cặp gốc-dịch
          // (đặt trong nhánh oneOf để không ràng lên type khác)
        },
        {
          properties: { type: { enum: ['text', 'speech', 'ai_chat'] } },
          required: ['sourceText', 'translatedText'],
        },
      ],
      // ràng buộc hình dạng segments (áp dụng khi field tồn tại)
      patternProperties: {},
    },
  },

  aiconversations: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['user'],
      properties: {
        user: objectId,
        title: str,
        summary: str,
        // Chặn anti-pattern "unbounded array" ngay tại DB: document Mongo trần 16MB,
        // hội thoại quá dài phải mở hội thoại mới (app chặn từ 200, DB chặn cứng 400).
        messages: {
          bsonType: 'array',
          maxItems: 400,
          items: {
            bsonType: 'object',
            required: ['role', 'content'],
            properties: {
              role: { enum: ['user', 'assistant'] },
              content: { ...str, minLength: 1 },
            },
          },
        },
      },
    },
  },
};

// bổ sung shape segments cho translationhistories (khi field có mặt)
validators.translationhistories.$jsonSchema.properties.segments = {
  bsonType: 'array',
  minItems: 1,
  items: {
    bsonType: 'object',
    required: ['sourceText', 'translatedText'],
    properties: {
      sourceText: { ...str, minLength: 1 },
      translatedText: { ...str, minLength: 1 },
      at: date,
    },
  },
};
delete validators.translationhistories.$jsonSchema.patternProperties;

async function main() {
  // autoIndex:false — không để Mongoose tự build index ngầm khi connect,
  // nếu không nó chạy đua với collMod bên dưới ("an index build is currently
  // running"); index được build CÓ KIỂM SOÁT ở bước syncIndexes phía sau.
  await mongoose.connect(process.env.MONGO_URI, { autoIndex: false });
  const db = mongoose.connection.db;
  const existing = new Set((await db.listCollections().toArray()).map((c) => c.name));

  // 1. Gắn validator
  for (const [coll, validator] of Object.entries(validators)) {
    if (!existing.has(coll)) {
      await db.createCollection(coll, {
        validator,
        validationLevel: 'moderate',
        validationAction: 'error',
      });
      console.log(`✅ createCollection + validator: ${coll}`);
    } else {
      await db.command({
        collMod: coll,
        validator,
        validationLevel: 'moderate',
        validationAction: 'error',
      });
      console.log(`✅ collMod validator: ${coll}`);
    }
  }

  // 2. Đồng bộ index theo khai báo trong Mongoose schema (drop index thừa)
  const models = [User, Language, Model, Vocabulary, SystemVocabulary, TranslationHistory, AIConversation];
  for (const m of models) {
    const dropped = await m.syncIndexes();
    const names = Object.keys(await m.collection.indexInformation());
    console.log(`🔄 ${m.collection.name}: index = [${names.join(', ')}]${dropped.length ? ` (đã drop: ${dropped.join(', ')})` : ''}`);
  }

  await mongoose.disconnect();
  console.log('\n🎉 Đồng bộ validator + index xong.');
}

main().catch((err) => {
  console.error('❌ sync-db thất bại:', err.message);
  process.exit(1);
});
