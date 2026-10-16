const Setting = require('../models/Setting');
const { encrypt, decrypt } = require('./crypto');

// Cache ngắn trong bộ nhớ để mỗi lần gọi AI không phải query DB.
// Được xóa ngay khi admin cập nhật cấu hình.
let cache = null;
let cacheAt = 0;
const TTL_MS = 30 * 1000;

const invalidate = () => {
  cache = null;
};

const loadAll = async () => {
  if (cache && Date.now() - cacheAt < TTL_MS) return cache;
  const docs = await Setting.find({ key: { $in: ['geminiApiKey', 'geminiModel'] } });
  const map = {};
  docs.forEach((d) => {
    map[d.key] = d.encrypted ? decrypt(d.value) : d.value;
  });
  cache = map;
  cacheAt = Date.now();
  return map;
};

// Ưu tiên giá trị admin nhập trong DB, không có thì dùng biến môi trường (.env)
const getGeminiConfig = async () => {
  const db = await loadAll();
  const apiKey = db.geminiApiKey || process.env.GEMINI_API_KEY || '';
  const model = db.geminiModel || process.env.GEMINI_MODEL || 'gemini-2.0-flash';
  return {
    apiKey,
    model,
    keySource: db.geminiApiKey ? 'database' : process.env.GEMINI_API_KEY ? 'env' : 'none',
    modelSource: db.geminiModel ? 'database' : 'env',
  };
};

const setSetting = async (key, value, { secret = false, userId } = {}) => {
  await Setting.findOneAndUpdate(
    { key },
    { key, value: secret ? encrypt(value) : value, encrypted: secret, updatedBy: userId },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
  invalidate();
};

const deleteSetting = async (key) => {
  await Setting.deleteOne({ key });
  invalidate();
};

module.exports = { getGeminiConfig, setSetting, deleteSetting, invalidate };
