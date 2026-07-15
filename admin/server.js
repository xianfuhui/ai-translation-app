require('dotenv').config();
const express = require('express');
const path = require('path');
const session = require('express-session');
const methodOverride = require('method-override');

const authRoutes = require('./src/routes/authRoutes');
const dashboardRoutes = require('./src/routes/dashboardRoutes');
const userRoutes = require('./src/routes/userRoutes');
const vocabularyRoutes = require('./src/routes/vocabularyRoutes');
const historyRoutes = require('./src/routes/historyRoutes');
const languageRoutes = require('./src/routes/languageRoutes');

const app = express();

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'src/views'));

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(methodOverride('_method'));
app.use(express.static(path.join(__dirname, 'public')));

app.use(
  session({
    secret: process.env.SESSION_SECRET || 'dev_secret',
    resave: false,
    saveUninitialized: false,
    cookie: { maxAge: 1000 * 60 * 60 * 8 }, // 8 giờ
  })
);

// Đưa thông tin admin đang đăng nhập vào mọi view
app.use((req, res, next) => {
  res.locals.admin = req.session?.admin || null;
  next();
});

app.get('/', (req, res) => res.redirect(req.session?.token ? '/dashboard' : '/login'));

app.use('/', authRoutes);
app.use('/', dashboardRoutes);
app.use('/', userRoutes);
app.use('/', vocabularyRoutes);
app.use('/', historyRoutes);
app.use('/', languageRoutes);

// Nếu token hết hạn / bị từ chối bởi backend (401/403), đẩy về trang login
app.use((err, req, res, next) => {
  console.error(err.message);
  if (err.response?.status === 401) {
    req.session.destroy(() => res.redirect('/login'));
    return;
  }
  res.status(500).send(`
    <div style="font-family: sans-serif; padding: 40px;">
      <h2>Đã có lỗi xảy ra</h2>
      <p>${err.response?.data?.message || err.message}</p>
      <a href="/dashboard">← Quay lại trang chủ</a>
    </div>
  `);
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log(`🖥️  Web Admin đang chạy tại http://localhost:${PORT}`));
