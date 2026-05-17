const app = require('./app');
const { assertRuntimeEnv, env } = require('./config/env');
const { setupRealtime } = require('./services/realtimeService');

assertRuntimeEnv();
setupRealtime();

app.listen(env.port, () => {
  console.log(`Pembukuan Express running at http://localhost:${env.port}`);
});
