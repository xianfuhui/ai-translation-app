const axios = require('axios');

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
const callGemini = async (contents) => {
  const model = process.env.GEMINI_MODEL || 'gemini-2.0-flash';
  const response = await axios.post(
    `${GEMINI_API_URL(model)}?key=${process.env.GEMINI_API_KEY}`,
    { contents },
    { headers: { 'Content-Type': 'application/json' } }
  );
  return response.data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
};

module.exports = { callGemini, truncateForLlm, MAX_LLM_INPUT_CHARS };
