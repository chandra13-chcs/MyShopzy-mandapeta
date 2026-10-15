const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const { createApp } = require('../../src/app');
const {
  createAuth0AdminAuthenticator,
} = require('../../src/modules/admin-read/auth0-authentication');

const adminId = 'a8c2ee15-7b78-4e88-a473-35b95647f419';
const audience = 'https://api.myshopzy.test';
const adminUserIdClaim = 'https://claims.example.test/admin_user_id';

async function startServer(t, server) {
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  }));
  return `http://127.0.0.1:${server.address().port}`;
}

async function createAuthFixture(t, userRows = [{ id: adminId }]) {
  const jose = await import('jose');
  const { publicKey, privateKey } = await jose.generateKeyPair('RS256');
  const jwk = {
    ...await jose.exportJWK(publicKey),
    alg: 'RS256',
    use: 'sig',
    kid: 'auth0-test-key',
  };
  const jwksServer = http.createServer((req, res) => {
    if (req.url !== '/.well-known/jwks.json') {
      res.writeHead(404).end();
      return;
    }
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ keys: [jwk] }));
  });
  const issuerUrl = `${await startServer(t, jwksServer)}/`;
  const queries = [];
  const databasePool = {
    async query(sql, params) {
      queries.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      if (/FROM app\.users/i.test(sql)) return { rows: userRows };
      if (/count\(\*\)/i.test(sql)) return { rows: [{ total: '0' }] };
      return { rows: [] };
    },
  };
  const authenticateAdmin = createAuth0AdminAuthenticator({
    databasePool,
    issuerUrl,
    audience,
    adminUserIdClaim,
  });
  const appServer = http.createServer(createApp({
    databasePool,
    authenticateAdmin,
    superAdminOrigin: 'http://localhost:5173',
  }));
  const baseUrl = await startServer(t, appServer);

  async function token(claims = {}, signingKey = privateKey) {
    const builder = new jose.SignJWT({
      [adminUserIdClaim]: adminId,
      ...claims,
    })
      .setProtectedHeader({ alg: 'RS256', kid: 'auth0-test-key', typ: 'JWT' })
      .setIssuer(claims.iss ?? issuerUrl)
      .setAudience(claims.aud ?? audience)
      .setSubject('auth0|verified-admin')
      .setIssuedAt()
      .setExpirationTime(claims.exp ?? '5m')
    if (claims.nbf !== undefined) builder.setNotBefore(claims.nbf)
    return builder.sign(signingKey)
  }

  return { baseUrl, databasePool, queries, token, jose };
}

test('verifies Auth0 JWT claims and resolves an active admin before reading', async (t) => {
  const fixture = await createAuthFixture(t);
  const accessToken = await fixture.token();
  const response = await fetch(`${fixture.baseUrl}/api/v1/admin/orders`, {
    headers: { authorization: `Bearer ${accessToken}` },
  });

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    data: [],
    meta: {
      pagination: { limit: 25, offset: 0, total: 0 },
      requestId: response.headers.get('x-request-id'),
    },
  });
  assert.equal(fixture.queries.filter(({ sql }) => /system_role = 'admin'/.test(sql)).length, 1);
  assert.match(fixture.queries[0].sql, /id = \$1::uuid/);
  assert.match(fixture.queries[0].sql, /system_role = 'admin'/);
  assert.match(fixture.queries[0].sql, /status = 'active'/);
  assert.deepEqual(
    fixture.queries.find(({ sql }) => /system_role = 'admin'/.test(sql)).params,
    [adminId],
  );
});

test('rejects missing, forged, expired, premature, wrong-issuer and wrong-audience tokens', async (t) => {
  const fixture = await createAuthFixture(t);
  const otherKey = await fixture.jose.generateKeyPair('RS256');
  const requests = [
    { headers: {} },
    { token: await fixture.token({}, otherKey.privateKey) },
    { token: await fixture.token({ exp: Math.floor(Date.now() / 1000) - 60 }) },
    { token: await fixture.token({ nbf: Math.floor(Date.now() / 1000) + 60 }) },
    { token: await fixture.token({ iss: 'https://attacker.example.test/' }) },
    { token: await fixture.token({ aud: 'https://other-api.example.test' }) },
  ];

  for (const request of requests) {
    const response = await fetch(`${fixture.baseUrl}/api/v1/admin/orders`, {
      headers: request.token
        ? { authorization: `Bearer ${request.token}` }
        : request.headers,
    });
    assert.equal(response.status, 401);
  }
  assert.equal(fixture.queries.length, 0);
});

test('requires the configured identity claim to map to exactly one active admin record', async (t) => {
  const fixture = await createAuthFixture(t, []);
  const response = await fetch(`${fixture.baseUrl}/api/v1/admin/orders`, {
    headers: { authorization: `Bearer ${await fixture.token()}` },
  });

  assert.equal(response.status, 403);
  assert.equal((await response.json()).error.code, 'ADMIN_ACCESS_REQUIRED');
  assert.equal(fixture.queries.length, 1);
});

test('serves browser preflight only to the configured Super Admin origin', async (t) => {
  const fixture = await createAuthFixture(t);
  const allowed = await fetch(`${fixture.baseUrl}/api/v1/admin/orders`, {
    method: 'OPTIONS',
    headers: {
      origin: 'http://localhost:5173',
      'access-control-request-method': 'GET',
      'access-control-request-headers': 'authorization',
    },
  });
  assert.equal(allowed.status, 204);
  assert.equal(allowed.headers.get('access-control-allow-origin'), 'http://localhost:5173');

  const denied = await fetch(`${fixture.baseUrl}/api/v1/admin/orders`, {
    method: 'OPTIONS',
    headers: { origin: 'https://unexpected.example.test' },
  });
  assert.equal(denied.status, 401);
  assert.equal(denied.headers.get('access-control-allow-origin'), null);
});
