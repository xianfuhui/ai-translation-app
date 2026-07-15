const axios = require('axios');

// Tạo 1 axios instance riêng cho mỗi request, gắn token của admin đang đăng nhập
const apiClient = (req) => {
  const instance = axios.create({
    baseURL: process.env.BACKEND_API_URL,
    headers: req.session?.token ? { Authorization: `Bearer ${req.session.token}` } : {},
  });
  return instance;
};

module.exports = apiClient;
