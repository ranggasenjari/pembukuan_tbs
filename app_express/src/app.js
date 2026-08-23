const path = require('path');
const express = require('express');
const session = require('express-session');
const methodOverride = require('method-override');
const morgan = require('morgan');
const { env } = require('./config/env');
const { requireAuth } = require('./middleware/auth');
const { publicAuth } = require('./middleware/publicAuth');
const { flashMiddleware } = require('./middleware/flash');
const { attachClient } = require('./services/realtimeService');
const format = require('./services/format');
const { stripBasePath, urlFor } = require('./services/url');

const authRoutes = require('./routes/authRoutes');
const dashboardRoutes = require('./routes/dashboardRoutes');
const bonRoutes = require('./routes/bonRoutes');
const notaRoutes = require('./routes/notaRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const depositRoutes = require('./routes/depositRoutes');
const marginRoutes = require('./routes/marginRoutes');
const expenseRoutes = require('./routes/expenseRoutes');
const relationAgentRoutes = require('./routes/relationAgentRoutes');
const paymentRelationRoutes = require('./routes/paymentRelationRoutes');
const bonManagementRoutes = require('./routes/bonManagementRoutes');
const transactionRoutes = require('./routes/transactionRoutes');
const factoryRoutes = require('./routes/factoryRoutes');
const vehicleRoutes = require('./routes/vehicleRoutes');
const apiRoutes = require('./routes/apiRoutes');
const apiV1Routes = require('./routes/apiV1Routes');
const reportRoutes = require('./routes/reportRoutes');
const publicRoutes = require('./routes/publicRoutes');
const bonPublikRoutes = require('./routes/bonPublikRoutes');
const settingsRoutes = require('./routes/settingsRoutes');

const app = express();
const publicDir = path.join(__dirname, '..', 'public');

app.set('trust proxy', 1);

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(express.static(publicDir));
if (env.basePath) {
  app.use(env.basePath, express.static(publicDir));
}
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
  const redirect = res.redirect.bind(res);
  res.redirect = (statusOrUrl, maybeUrl) => {
    if (typeof statusOrUrl === 'string') return redirect(urlFor(statusOrUrl, env.basePath));
    return redirect(statusOrUrl, urlFor(maybeUrl, env.basePath));
  };

  res.locals.format = format;
  res.locals.basePath = env.basePath;
  res.locals.url = (target) => urlFor(target, env.basePath);
  res.locals.path = stripBasePath(req.path, env.basePath);
  next();
});

const mainRouter = express.Router();

mainRouter.use(authRoutes);

// Swagger docs — public (sebelum apiV1Routes)
const swaggerPath = path.join(__dirname, '..', 'docs', 'swagger.json');
mainRouter.get('/api/docs', (req, res) => {
  const base = env.basePath || '';
  const jsonUrl = base + '/api/v1/swagger.json';
  res.send(`<!DOCTYPE html>
<html lang="id"><head><meta charset="UTF-8"><title>API Docs</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui.css">
</head><body><div id="swagger-ui"></div>
<script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
<script>SwaggerUIBundle({url:'${jsonUrl}',dom_id:'#swagger-ui',presets:[SwaggerUIBundle.presets.apis],layout:'BaseLayout'});</script>
</body></html>`);
});
mainRouter.get('/api/v1/swagger.json', (req, res) => {
  const base = env.basePath || '';
  const swagger = require(swaggerPath);
  swagger.servers = [{ url: base + '/api/v1', description: 'API v1' }];
  res.json(swagger);
});

mainRouter.use('/api/v1', apiV1Routes);
mainRouter.use(publicAuth);
mainRouter.use(publicRoutes);
mainRouter.use(bonPublikRoutes);
// SSE events — public (no auth) agar client bisa connect
mainRouter.get('/api/events', (req, res) => attachClient(req, res));
mainRouter.use(requireAuth);
mainRouter.use(dashboardRoutes);
mainRouter.use('/bons', bonRoutes);
mainRouter.use('/bon-management', bonManagementRoutes);
mainRouter.use('/relation-agents', relationAgentRoutes);
mainRouter.use('/payment-relations', paymentRelationRoutes);
mainRouter.use('/transactions', transactionRoutes);
mainRouter.use('/factories', factoryRoutes);
mainRouter.use('/vehicles', vehicleRoutes);
mainRouter.use('/notas', notaRoutes);
mainRouter.use('/payments', paymentRoutes);
mainRouter.use('/deposits', depositRoutes);
mainRouter.use('/margins', marginRoutes);
mainRouter.use('/expenses', expenseRoutes);
mainRouter.use('/settings', settingsRoutes);
mainRouter.use('/api', apiRoutes);
mainRouter.use('/reports', reportRoutes);

if (env.basePath) {
  app.use(env.basePath, mainRouter);
}
app.use(mainRouter);

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
