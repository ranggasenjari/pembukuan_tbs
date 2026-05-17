const path = require('path');
const express = require('express');
const session = require('express-session');
const methodOverride = require('method-override');
const morgan = require('morgan');
const { env } = require('./config/env');
const { requireAuth } = require('./middleware/auth');
const { flashMiddleware } = require('./middleware/flash');
const format = require('./services/format');

const authRoutes = require('./routes/authRoutes');
const dashboardRoutes = require('./routes/dashboardRoutes');
const bonRoutes = require('./routes/bonRoutes');
const notaRoutes = require('./routes/notaRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const depositRoutes = require('./routes/depositRoutes');
const marginRoutes = require('./routes/marginRoutes');
const expenseRoutes = require('./routes/expenseRoutes');
const apiRoutes = require('./routes/apiRoutes');
const apiV1Routes = require('./routes/apiV1Routes');
const reportRoutes = require('./routes/reportRoutes');

const app = express();

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(express.static(path.join(__dirname, '..', 'public')));
app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(methodOverride('_method'));
app.use(morgan(env.nodeEnv === 'production' ? 'combined' : 'dev'));
app.use(
  session({
    secret: env.sessionSecret,
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      sameSite: 'lax',
      secure: env.nodeEnv === 'production',
      maxAge: 1000 * 60 * 60 * 12
    }
  })
);
app.use(flashMiddleware);

app.use((req, res, next) => {
  res.locals.format = format;
  res.locals.path = req.path;
  next();
});

app.use(authRoutes);
app.use('/api/v1', apiV1Routes);
app.use(requireAuth);
app.use(dashboardRoutes);
app.use('/bons', bonRoutes);
app.use('/notas', notaRoutes);
app.use('/payments', paymentRoutes);
app.use('/deposits', depositRoutes);
app.use('/margins', marginRoutes);
app.use('/expenses', expenseRoutes);
app.use('/api', apiRoutes);
app.use('/reports', reportRoutes);

app.use((req, res) => {
  res.status(404).render('partials/error', { title: 'Tidak ditemukan', error: new Error('Halaman tidak ditemukan.') });
});

app.use((error, req, res, next) => {
  console.error(error);
  const status = error.status || 500;
  res.status(status);
  if (req.accepts('html')) {
    return res.render('partials/error', { title: 'Error', error });
  }
  return res.json({ error: error.message });
});

module.exports = app;
