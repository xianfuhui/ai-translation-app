const { getGeminiConfig, setSetting, deleteSetting } = require('../utils/appSettings');
const { callGemini } = require('../utils/gemini');

// Chỉ trả về dạng che (AIza••••abcd), tuyệt đối không trả key đầy đủ ra ngoài
const maskKey = (key) => {
  if (!key) return '';
  if (key.length <= 8) return '••••••••';
  return `${key.slice(0, 4)}••••••••${key.slice(-4)}`;
};

const describe = async () => {
  const c = await getGeminiConfig();
  return {
    hasKey: !!c.apiKey,
    maskedKey: maskKey(c.apiKey),
    keySource: c.keySource, // 'database' | 'env' | 'none'
    model: c.model,
    modelSource: c.modelSource,
  };
};

// @desc    Xem cấu hình Gemini hiện tại (key được che)
// @route   GET /api/settings/gemini
const getGemini = async (req, res, next) => {
  try {
    res.json(await describe());
  } catch (error) {
    next(error);
  }
};

// @desc    Admin nhập/đổi Gemini API key và/hoặc model
// @route   PUT /api/settings/gemini   body: { apiKey?, model? }
const updateGemini = async (req, res, next) => {
  try {
    const apiKey = (req.body.apiKey || '').trim();
    const model = (req.body.model || '').trim();

    if (!apiKey && !model) {
      return res.status(400).json({ message: 'Vui lòng nhập API key hoặc tên model' });
    }
    if (apiKey && (apiKey.length < 20 || /\s/.test(apiKey))) {
      return res.status(400).json({ message: 'API key không hợp lệ (quá ngắn hoặc có khoảng trắng)' });
    }
    if (model && !/^[\w.\-]+$/.test(model)) {
      return res.status(400).json({ message: 'Tên model không hợp lệ' });
    }

    if (apiKey) await setSetting('geminiApiKey', apiKey, { secret: true, userId: req.user._id });
    if (model) await setSetting('geminiModel', model, { userId: req.user._id });

    res.json({ message: 'Đã lưu cấu hình Gemini', ...(await describe()) });
  } catch (error) {
    next(error);
  }
};

// @desc    Xóa key/model đã nhập trong DB -> quay lại dùng giá trị trong .env
// @route   DELETE /api/settings/gemini
const resetGemini = async (req, res, next) => {
  try {
    await deleteSetting('geminiApiKey');
    await deleteSetting('geminiModel');
    res.json({ message: 'Đã xóa cấu hình đã nhập, quay lại dùng .env', ...(await describe()) });
  } catch (error) {
    next(error);
  }
};

// @desc    Gọi thử Gemini để kiểm tra key (dùng key mới nhập chưa lưu, hoặc key đang dùng)
// @route   POST /api/settings/gemini/test   body: { apiKey?, model? }
const testGemini = async (req, res) => {
  try {
    const apiKey = (req.body.apiKey || '').trim() || undefined;
    const model = (req.body.model || '').trim() || undefined;
    await callGemini([{ role: 'user', parts: [{ text: 'Trả lời đúng một từ: OK' }] }], { apiKey, model });
    res.json({ ok: true, message: 'Kết nối Gemini thành công' });
  } catch (error) {
    if (error.code === 'NO_GEMINI_KEY') return res.status(400).json({ ok: false, message: error.message });
    const detail = error.response?.data?.error?.message || error.message;
    res.status(400).json({ ok: false, message: `Gemini từ chối: ${detail}` });
  }
};

module.exports = { getGemini, updateGemini, resetGemini, testGemini };
