const { createApp } = require('./app');
const { register, setAppInfo } = require('./metrics');

const PORT = Number(process.env.PORT || 8080);
const VERSION = process.env.VERSION || 'dev';
const COMMIT = process.env.COMMIT || 'unknown';
// Mốc build time được Helm truyền vào khi render (mặc định = lúc deploy)
const BUILT_AT = Number(process.env.BUILT_AT || Date.now());

const app = createApp();

// Endpoint Prometheus scrape
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

setAppInfo({ version: VERSION, commit: COMMIT, builtAt: BUILT_AT });

app.listen(PORT, () => {
  console.log(`[${VERSION}@${COMMIT}] listening on :${PORT}`);
});
