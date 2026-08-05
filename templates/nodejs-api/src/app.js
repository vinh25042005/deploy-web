const express = require('express');

/**
 * Tách app khỏi phần listen để dễ unit test (node --test).
 */
function createApp() {
  const app = express();
  app.use(express.json());

  // Health check — dùng cho readiness/liveness probe của K8s
  app.get('/health', (req, res) => {
    res.json({ status: 'ok', uptime: process.uptime() });
  });

  app.get('/', (req, res) => {
    res.json({
      service: process.env.SERVICE_NAME || 'nodejs-api',
      version: process.env.VERSION || 'dev',
      commit: process.env.COMMIT || 'unknown',
      message: 'OK',
    });
  });

  return app;
}

module.exports = { createApp };
