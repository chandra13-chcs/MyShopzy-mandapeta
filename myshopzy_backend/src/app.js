const express = require('express');
const { isDatabaseReady } = require('./config/database');

function createApp({ databasePool = null } = {}) {
  const app = express();

  app.use(express.json());

  app.get('/health', (req, res) => {
    res.status(200).json({ status: 'ok' });
  });

  app.get('/health/ready', async (req, res) => {
    const ready = await isDatabaseReady(databasePool);
    res.status(ready ? 200 : 503).json({
      status: ready ? 'ready' : 'not_ready',
    });
  });

  return app;
}

module.exports = createApp();
module.exports.createApp = createApp;
