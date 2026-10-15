const assert = require('node:assert/strict');
const { mkdtemp, mkdir, readFile, rm, writeFile } = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const {
  readMigrations,
  runMigrations,
} = require('../../src/database/migrate');

const schemaPath = path.resolve(
  __dirname,
  '../../database/migrations/001_initial_multi_partner_schema.sql',
);
const cartsSchemaPath = path.resolve(
  __dirname,
  '../../database/migrations/002_customer_carts.sql',
);
const customerAccountSchemaPath = path.resolve(
  __dirname,
  '../../database/migrations/003_customer_account_parcels.sql',
);
const dynamicCategoriesSchemaPath = path.resolve(
  __dirname,
  '../../database/migrations/004_dynamic_partner_categories_and_delivery_zones.sql',
);

function createMockPool({ applied = new Map(), failure } = {}) {
  const calls = [];
  let released = false;
  const client = {
    async query(sql, params = []) {
      calls.push({ sql: sql.trim(), params });
      if (failure && sql.trim().startsWith(failure.sql)) throw failure.error;
      if (sql.startsWith('SELECT checksum')) {
        const record = applied.get(params[0]);
        return {
          rowCount: record ? 1 : 0,
          rows: record ? [{ checksum: record.checksum }] : [],
        };
      }
      if (sql.startsWith('INSERT INTO public.schema_migrations')) {
        applied.set(params[0], { checksum: params[2], name: params[1] });
      }
      return { rowCount: 0, rows: [] };
    },
    release() {
      released = true;
    },
  };

  return {
    calls,
    applied,
    get released() {
      return released;
    },
    async connect() {
      return client;
    },
  };
}

test('orders migrations, calculates checksums, and rejects duplicate versions', async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'myshopzy-migrations-'));
  try {
    await writeFile(path.join(directory, '002_second.sql'), 'SELECT 2;');
    await writeFile(path.join(directory, '001_first.sql'), 'SELECT 1;');
    const migrations = await readMigrations(directory);
    assert.deepEqual(migrations.map((migration) => migration.version), ['001', '002']);
    assert.match(migrations[0].checksum, /^[a-f0-9]{64}$/);

    await writeFile(path.join(directory, '001_duplicate.sql'), 'SELECT 3;');
    await assert.rejects(readMigrations(directory), /Duplicate migration version 001/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('rejects unexpected SQL filenames rather than silently skipping them', async () => {
  const directory = await mkdtemp(path.join(os.tmpdir(), 'myshopzy-migrations-'));
  try {
    await writeFile(path.join(directory, '001_valid.sql'), 'SELECT 1;');
    await writeFile(path.join(directory, 'schema.sql'), 'SELECT 2;');

    await assert.rejects(
      readMigrations(directory),
      /Unexpected SQL migration filename\(s\): schema\.sql/,
    );
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('applies an unapplied migration transactionally and records its checksum', async () => {
  const pool = createMockPool();
  const appliedCount = await runMigrations(pool);
  const schema = await readFile(schemaPath, 'utf8');
  const cartsSchema = await readFile(cartsSchemaPath, 'utf8');
  const customerAccountSchema = await readFile(customerAccountSchemaPath, 'utf8');
  const dynamicCategoriesSchema = await readFile(dynamicCategoriesSchemaPath, 'utf8');
  const calls = pool.calls.map((call) => call.sql);

  assert.equal(appliedCount, 4);
  assert.equal(pool.applied.get('001').name, '001_initial_multi_partner_schema.sql');
  assert.equal(pool.applied.get('002').name, '002_customer_carts.sql');
  assert.equal(
    pool.applied.get('003').name,
    '003_customer_account_parcels.sql',
  );
  assert.equal(
    pool.applied.get('004').name,
    '004_dynamic_partner_categories_and_delivery_zones.sql',
  );
  assert.ok(calls.includes('BEGIN'));
  assert.ok(calls.includes(schema.trim()));
  assert.ok(calls.includes(cartsSchema.trim()));
  assert.ok(calls.includes(customerAccountSchema.trim()));
  assert.ok(calls.includes(dynamicCategoriesSchema.trim()));
  assert.ok(calls.includes('COMMIT'));
  assert.ok(calls.includes('SELECT pg_advisory_lock($1, $2)'));
  assert.ok(calls.includes('SELECT pg_advisory_unlock($1, $2)'));
  assert.equal(pool.released, true);
});

test('dynamic category and serviceability migration supports live partner types', async () => {
  const schema = await readFile(dynamicCategoriesSchemaPath, 'utf8');

  assert.match(schema, /DROP CONSTRAINT partners_partner_type_check/);
  assert.match(schema, /partner_type_format_check/);
  assert.match(schema, /GENERATED ALWAYS AS \(status = 'approved'\) STORED/);
  assert.match(schema, /CREATE TABLE app\.serviceable_pincodes\b/);
  assert.match(schema, /pincode ~ '\^\[0-9\]\{6\}\$'/);
});

test('customer account migration adds address, wishlist, and parcel foundations', async () => {
  const schema = await readFile(customerAccountSchemaPath, 'utf8');

  assert.match(schema, /CREATE TABLE app\.customer_saved_addresses\b/);
  assert.match(schema, /address_snapshot jsonb NOT NULL/);
  assert.match(schema, /CREATE TABLE app\.customer_wishlist_items\b/);
  assert.match(schema, /REFERENCES app\.products \(id, shop_id, partner_id\)/);
  assert.match(schema, /CREATE TABLE app\.parcel_bookings\b/);
  assert.match(schema, /weight_grams integer NOT NULL CHECK \(weight_grams BETWEEN 1 AND 20000\)/);
  assert.match(schema, /status text NOT NULL DEFAULT 'requested'/);
});

test('cart migration adds token-protected single-shop cart persistence', async () => {
  const schema = await readFile(cartsSchemaPath, 'utf8');

  assert.match(schema, /CREATE TABLE app\.customer_carts\b/);
  assert.match(schema, /token_hash bytea NOT NULL UNIQUE/);
  assert.match(schema, /octet_length\(token_hash\) = 32/);
  assert.match(schema, /CHECK \(\(shop_id IS NULL\) = \(partner_id IS NULL\)\)/);
  assert.match(schema, /CREATE TABLE app\.customer_cart_items\b/);
  assert.match(schema, /quantity integer NOT NULL CHECK \(quantity BETWEEN 1 AND 99\)/);
  assert.match(schema, /REFERENCES app\.products \(id, shop_id, partner_id\)/);
});

test('skips matching applied migrations and refuses checksum drift', async () => {
  const migration = (await readMigrations(path.dirname(schemaPath)))[0];
  const alreadyApplied = createMockPool({
    applied: new Map([['001', { checksum: migration.checksum }]]),
  });
  assert.equal(await runMigrations(alreadyApplied), 4);
  assert.equal(
    alreadyApplied.calls.some((call) => call.sql === migration.sql.trim()),
    false,
  );
  assert.ok(
    alreadyApplied.calls.some((call) =>
      call.sql.startsWith('CREATE TABLE app.customer_carts'),
    ),
  );

  const changed = createMockPool({
    applied: new Map([['001', { checksum: '0'.repeat(64) }]]),
  });
  await assert.rejects(
    runMigrations(changed),
    /Applied migration 001 has changed/,
  );
  assert.equal(changed.released, true);
});

test('rolls back a failed migration and releases the client', async () => {
  const pool = createMockPool({
    failure: {
      sql: 'CREATE SCHEMA app;',
      error: new Error('database error'),
    },
  });

  await assert.rejects(runMigrations(pool), /database error/);
  const calls = pool.calls.map((call) => call.sql);
  assert.ok(calls.includes('ROLLBACK'));
  assert.equal(calls.includes('COMMIT'), false);
  assert.equal(pool.released, true);
});

test('schema encodes multi-partner ownership and immutable order snapshots', async () => {
  const schema = await readFile(schemaPath, 'utf8');

  for (const table of [
    'partners',
    'partner_memberships',
    'customers',
    'riders',
    'shops',
    'categories',
    'products',
    'orders',
    'order_items',
  ]) {
    assert.match(schema, new RegExp(`CREATE TABLE app\\.${table}\\b`));
  }

  assert.match(
    schema,
    /FOREIGN KEY \(shop_id, partner_id\)\s+REFERENCES app\.shops \(id, partner_id\)/,
  );
  assert.match(
    schema,
    /UNIQUE \(id, partner_id, shop_id, currency\)/,
  );
  assert.match(
    schema,
    /FOREIGN KEY \(order_id, partner_id, shop_id, currency\)\s+REFERENCES app\.orders \(id, partner_id, shop_id, currency\)/,
  );
  assert.match(schema, /product_name_snapshot text NOT NULL/);
  assert.match(schema, /CREATE TRIGGER order_items_immutable/);
  assert.doesNotMatch(schema, /ENABLE ROW LEVEL SECURITY/);
});

test('documents the pending database tenant-isolation boundary', async () => {
  const readme = await readFile(
    path.resolve(__dirname, '../../README.md'),
    'utf8',
  );

  assert.match(readme, /Row-level security is not enabled/);
  assert.match(readme, /not protected by a database tenant boundary/);
  assert.match(readme, /does not own the tables or have `BYPASSRLS`/);
});
