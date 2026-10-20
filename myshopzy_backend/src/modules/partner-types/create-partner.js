#!/usr/bin/env node
const { createDatabasePool } = require('../../config/database');
const { loadConfig } = require('../../config/env');
const { createPartnerWithDefaults } = require('./onboarding-service');

function parseArguments(args) {
  const values = {};
  for (let index = 0; index < args.length; index++) {
    const key = args[index];
    if (!['--type', '--name', '--email', '--phone', '--shop-name'].includes(key)) {
      throw new Error(`Unknown argument: ${key}`);
    }
    const value = args[index + 1];
    if (!value || value.startsWith('--')) {
      throw new Error(`A value is required for ${key}.`);
    }
    const property = {
      '--type': 'type',
      '--name': 'name',
      '--email': 'email',
      '--phone': 'phone',
      '--shop-name': 'shopName',
    }[key];
    if (Object.hasOwn(values, property)) {
      throw new Error(`${key} may only be supplied once.`);
    }
    values[property] = value;
    index++;
  }

  const optionNames = {
    type: '--type',
    name: '--name',
    email: '--email',
    phone: '--phone',
    shopName: '--shop-name',
  };
  const missing = Object.entries(optionNames)
    .filter(([property]) => !values[property])
    .map(([, option]) => option);
  if (missing.length > 0) {
    throw new Error(`Missing required options: ${missing.join(', ')}.`);
  }
  return values;
}

async function main(args = process.argv.slice(2)) {
  require('dotenv').config();
  const values = parseArguments(args);
  const config = loadConfig();
  if (!config.database) {
    throw new Error('PostgreSQL configuration is required to create a partner.');
  }
  const pool = createDatabasePool(config.database);
  try {
    const created = await createPartnerWithDefaults({
      databasePool: pool,
      name: values.name,
      type: values.type,
      ownerEmail: values.email,
      ownerPhone: values.phone,
      shop: { name: values.shopName },
    });
    console.log(JSON.stringify({
      partnerId: created.partner.id,
      ownerUserId: created.user.id,
      shopId: created.shop.id,
      categoryCount: created.categories.length,
      note: 'The owner signs in through Auth0 using the configured email.',
    }, null, 2));
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = { main, parseArguments };
