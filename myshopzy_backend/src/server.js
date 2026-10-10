require('dotenv').config();

const app = require('./app');

const port = Number(process.env.PORT || 3000);

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error('PORT must be an integer between 1 and 65535.');
}

const server = app.listen(port, () => {
  console.log(`MyShopzy backend listening on port ${port}`);
});

server.on('error', (error) => {
  console.error(`Unable to start MyShopzy backend: ${error.message}`);
  process.exitCode = 1;
});
