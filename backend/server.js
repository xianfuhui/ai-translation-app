require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const connectDB = require('./src/config/db');
const { notFound, errorHandler } = require('./src/middleware/errorHandler');

// Routes
const authRoutes = require('./src/routes/authRoutes');
const userRoutes = require('./src/routes/userRoutes');
const aiRoutes = require('./src/routes/aiRoutes');
const vocabularyRoutes = require('./src/routes/vocabularyRoutes');
const historyRoutes = require('./src/routes/historyRoutes');
const languageRoutes = require('./src/routes/languageRoutes');
const statsRoutes = require('./src/routes/statsRoutes');

const app = express();

// Kết nối MongoDB
connectDB();

// Middleware chung
app.use(cors());
app.use(express.json({ limit: '5mb' }));
app.use(morgan('dev'));

// Health check
app.get('/api/health', (req, res) => res.json({ status: 'ok', time: new Date() }));

// Gắn route theo từng module
app.use('/api/auth', authRoutes); // Quản lý tài khoản
app.use('/api/users', userRoutes); // Quản lý tài khoản người dùng (Admin)
app.use('/api/ai', aiRoutes); // AI Assistant (Gemini)
app.use('/api/vocabulary', vocabularyRoutes); // Quản lý từ vựng + Flashcard
app.use('/api/history', historyRoutes); // Lịch sử hoạt động
app.use('/api/languages', languageRoutes); // Ngôn ngữ hỗ trợ
app.use('/api/stats', statsRoutes); // Thống kê hệ thống (Admin)

// Xử lý lỗi
app.use(notFound);
app.use(errorHandler);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`🚀 Server đang chạy tại http://localhost:${PORT}`));
