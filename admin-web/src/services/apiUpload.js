const axios = require('axios');
const FormData = require('form-data');

/**
 * Gửi request multipart/form-data tới backend (dùng cho upload file model).
 * @param {object} req - Express request (cần req.session.token)
 * @param {'post'|'put'} method
 * @param {string} path - vd '/models' hoặc '/models/123'
 * @param {object} fields - các field text thường
 * @param {object|null} file - req.file từ multer (memoryStorage): { buffer, originalname, mimetype }
 */
async function apiUpload(req, method, path, fields, file) {
  const form = new FormData();
  Object.entries(fields).forEach(([key, value]) => {
    if (value !== undefined && value !== null) form.append(key, value);
  });
  if (file) {
    form.append('modelFile', file.buffer, { filename: file.originalname, contentType: file.mimetype });
  }

  const headers = {
    ...form.getHeaders(),
    ...(req.session?.token ? { Authorization: `Bearer ${req.session.token}` } : {}),
  };

  const url = `${process.env.BACKEND_API_URL}${path}`;
  const response = await axios({
    method,
    url,
    data: form,
    headers,
    maxBodyLength: Infinity,
    maxContentLength: Infinity,
  });
  return response.data;
}

module.exports = apiUpload;
