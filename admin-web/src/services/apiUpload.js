const axios = require('axios');
const FormData = require('form-data');

/**
 * Gửi request multipart/form-data tới backend.
 * @param {object} req            - Express request (cần req.session.token)
 * @param {'post'|'put'} method
 * @param {string} path           - vd '/vocabulary/system/import' hoặc '/models'
 * @param {object} fields         - các field text thường
 * @param {object|null} file      - req.file từ multer (memoryStorage): { buffer, originalname, mimetype }
 * @param {string} [fileField]    - tên field file trong form gửi đến backend (mặc định: 'file')
 */
async function apiUpload(req, method, path, fields, file, fileField = 'file') {
  const form = new FormData();
  Object.entries(fields).forEach(([key, value]) => {
    if (value !== undefined && value !== null) form.append(key, value);
  });
  if (file) {
    form.append(fileField, file.buffer, { filename: file.originalname, contentType: file.mimetype });
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
