const axios = require('axios');
const { getGeminiConfig } = require('./appSettings');

const GEMINI_API_URL = (model) =>
  `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

// Giới hạn số ký tự tối đa gửi cho LLM trong 1 lần gọi (tránh vượt quota/token
// và tránh phí quá cao khi hội thoại quá dài). Có thể cấu hình qua biến môi
// trường GEMINI_MAX_INPUT_CHARS, mặc định 8000 ký tự.
const MAX_LLM_INPUT_CHARS = parseInt(process.env.GEMINI_MAX_INPUT_CHARS, 10) || 8000;

/**
 * Cắt bớt văn bản nếu vượt quá giới hạn ký tự cho phép gửi tới LLM.
 * Giữ lại phần ĐẦU (bối cảnh mở đầu hội thoại) và phần CUỐI (nội dung gần nhất,
 * thường quan trọng nhất khi tóm tắt), lược bớt đoạn giữa nếu quá dài.
 */
const truncateForLlm = (text, maxChars = MAX_LLM_INPUT_CHARS) => {
  if (!text || text.length <= maxChars) return { text: text || '', truncated: false };

  const headChars = Math.floor(maxChars * 0.6);
  const tailChars = maxChars - headChars - 40; // chừa chỗ cho ghi chú lược bớt
  const head = text.slice(0, headChars);
  const tail = tailChars > 0 ? text.slice(-tailChars) : '';

  return {
    text: `${head}\n\n[... đã lược bớt một phần nội dung do vượt giới hạn ký tự ...]\n\n${tail}`,
    truncated: true,
  };
};

// Gọi Gemini API với danh sách nội dung (contents)
// API key + model lấy từ cấu hình admin nhập (DB), fallback về .env
const callGemini = async (contents, overrides = {}) => {
  const config = await getGeminiConfig();
  const apiKey = overrides.apiKey || config.apiKey;
  const model = overrides.model || config.model;

  if (!apiKey) {
    const err = new Error('Chưa cấu hình Gemini API key. Admin vui lòng nhập tại trang Cài đặt.');
    err.code = 'NO_GEMINI_KEY';
    throw err;
  }

  // Gửi key qua header thay vì query string để không lộ trong log URL
  const response = await axios.post(
    GEMINI_API_URL(model),
    { contents },
    { headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey } }
  );
  return response.data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
};

module.exports = { callGemini, truncateForLlm, MAX_LLM_INPUT_CHARS };
