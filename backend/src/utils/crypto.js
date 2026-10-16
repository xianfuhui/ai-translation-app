const crypto = require('crypto');

// Mã hóa AES-256-GCM để lưu các bí mật (vd: Gemini API key) trong DB, không để plaintext.
// Khóa lấy từ SETTINGS_ENCRYPTION_KEY (nên đặt riêng); nếu chưa có thì dùng JWT_SECRET.
// Lưu ý: đổi khóa này sau khi đã lưu key thì key cũ sẽ không giải mã được -> admin nhập lại.
const getKey = () => {
  const secret = process.env.SETTINGS_ENCRYPTION_KEY || process.env.JWT_SECRET;
  if (!secret) throw new Error('Thiếu SETTINGS_ENCRYPTION_KEY hoặc JWT_SECRET để mã hóa cấu hình');
  return crypto.createHash('sha256').update(secret).digest();
};

const encrypt = (plain) => {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', getKey(), iv);
  const enc = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return [iv, tag, enc].map((b) => b.toString('base64')).join(':');
};

const decrypt = (payload) => {
  try {
    const [iv, tag, enc] = payload.split(':').map((s) => Buffer.from(s, 'base64'));
    const decipher = crypto.createDecipheriv('aes-256-gcm', getKey(), iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(enc), decipher.final()]).toString('utf8');
  } catch (e) {
    return null; // sai khóa / dữ liệu hỏng
  }
};

module.exports = { encrypt, decrypt };
