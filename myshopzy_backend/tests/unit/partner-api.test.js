const assert = require('node:assert/strict');
const http = require('node:http');
const test = require('node:test');
const { createApp } = require('../../src/app');
const {
  createPartnerAuthenticator,
} = require('../../src/modules/partner-types/auth0-authentication');

const userId = 'a8c2ee15-7b78-4e88-a473-35b95647f419';
const partnerId = 'ae472331-037a-4e93-9c9a-47ee2b945111';
const shopId = '6b4fc632-943f-41be-9251-bac9307815bb';
const audience = 'https://api.myshopzy.test';

async function startServer(t, server) {
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  }));
  return `http://127.0.0.1:${server.address().port}`;
}

async function createFixture(t, { memberships = [] } = {}) {
  const jose = await import('jose');
  const { publicKey, privateKey } = await jose.generateKeyPair('RS256');
  const jwk = {
    ...await jose.exportJWK(publicKey),
    alg: 'RS256',
    use: 'sig',
    kid: 'partner-test-key',
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
  const calls = [];
  const databasePool = {
    async query(sql, params) {
      calls.push({ sql: sql.replace(/\s+/g, ' ').trim(), params });
      if (/FROM app\.users/i.test(sql)) {
        return { rows: [{ id: userId }] };
      }
      if (/FROM app\.partner_memberships/i.test(sql)) {
        return { rows: memberships };
      }
      if (/FROM app\.partners/i.test(sql)) {
        return {
          rows: [{
            id: partnerId,
            name: 'Demo Meat Shop',
            partner_type: 'meat',
            status: 'pending',
            contact_email: 'owner@example.test',
            contact_phone: '+919876543210',
            timezone: 'Asia/Kolkata',
          }],
        };
      }
      if (/FROM app\.shops/i.test(sql)) {
        return {
          rows: [{
            id: shopId,
            name: 'Main Shop',
            slug: 'main-shop',
            status: 'pending',
            address: {
              line1: '12 Market Road',
              city: 'Mandapeta',
              postalCode: '533308',
            },
            operating_details: { open: '08:30', close: '20:00' },
          }],
        };
      }
      return { rows: [] };
    },
  };
  const authenticatePartner = createPartnerAuthenticator({
    databasePool,
    issuerUrl,
    audience,
  });
  const appServer = http.createServer(createApp({
    databasePool,
    authenticatePartner,
    partnerPortalOrigins: ['http://localhost:5173'],
  }));
  const baseUrl = await startServer(t, appServer);

  async function token({ email = 'owner@example.test', emailVerified = true } = {}) {
    return new jose.SignJWT({
      email,
      email_verified: emailVerified,
    })
      .setProtectedHeader({ alg: 'RS256', kid: 'partner-test-key', typ: 'JWT' })
      .setIssuer(issuerUrl)
      .setAudience(audience)
      .setSubject('auth0|partner-owner')
      .setIssuedAt()
      .setExpirationTime('5m')
      .sign(privateKey);
  }

  return { baseUrl, calls, token };
}

test('rejects requests without a bearer token without querying the database', async (t) => {
  const fixture = await createFixture(t);
  const response = await fetch(`${fixture.baseUrl}/api/v1/partner/me/config`);

  assert.equal(response.status, 401);
  assert.equal((await response.json()).error.code, 'AUTHENTICATION_REQUIRED');
  assert.equal(fixture.calls.length, 0);
});

test('rejects an authenticated user without an active partner membership', async (t) => {
  const fixture = await createFixture(t);
  const response = await fetch(`${fixture.baseUrl}/api/v1/partner/me/config`, {
    headers: { authorization: `Bearer ${await fixture.token()}` },
  });

  assert.equal(response.status, 403);
  assert.equal((await response.json()).error.code, 'PARTNER_MEMBERSHIP_REQUIRED');
  assert.equal(fixture.calls.length, 2);
});

test('returns the authenticated partner profile and shop basics without trusting request IDs', async (t) => {
  const fixture = await createFixture(t, {
    memberships: [{
      partner_id: partnerId,
      role: 'owner',
      partner_type: 'meat',
      shop_ids: [shopId],
    }],
  });
  const response = await fetch(
    `${fixture.baseUrl}/api/v1/partner/me/config?partnerId=attacker-controlled`,
    {
      headers: {
        authorization: `Bearer ${await fixture.token()}`,
        origin: 'http://localhost:5173',
      },
    },
  );
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get('access-control-allow-origin'), 'http://localhost:5173');
  assert.equal(body.data.profile.label, 'Meat');
  assert.deepEqual(body.data.profile.allowedUnits, ['g', 'kg']);
  assert.deepEqual(body.data.partner, {
    id: partnerId,
    name: 'Demo Meat Shop',
    type: 'meat',
    status: 'pending',
    contactEmail: 'owner@example.test',
    contactPhone: '+919876543210',
    timezone: 'Asia/Kolkata',
  });
  assert.deepEqual(body.data.shops, [{
    id: shopId,
    name: 'Main Shop',
    slug: 'main-shop',
    status: 'pending',
    address: {
      line1: '12 Market Road',
      city: 'Mandapeta',
      postalCode: '533308',
    },
    operatingDetails: { open: '08:30', close: '20:00' },
  }]);
  assert.deepEqual(
    fixture.calls.find(({ sql }) => /FROM app\.partners/.test(sql)).params,
    [partnerId],
  );
  assert.deepEqual(
    fixture.calls.find(({ sql }) => /FROM app\.shops/.test(sql)).params,
    [partnerId],
  );
});

test('does not expose a partner endpoint for setting category codes or commission rates', async (t) => {
  const fixture = await createFixture(t, {
    memberships: [{
      partner_id: partnerId,
      role: 'owner',
      partner_type: 'meat',
      shop_ids: [shopId],
    }],
  });
  const response = await fetch(`${fixture.baseUrl}/api/v1/partner/categories`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${await fixture.token()}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      name: 'Frozen Foods',
      category_code: 'frozen_foods',
      commission_bps_override: 0,
    }),
  });

  assert.equal(response.status, 404);
  assert.equal((await response.json()).error.code, 'NOT_FOUND');
  assert.equal(
    fixture.calls.some(({ sql }) => /INSERT INTO app\.categories|UPDATE app\.categories/.test(sql)),
    false,
  );
});

test('rejects a validly signed Auth0 token without a verified email claim', async (t) => {
  const fixture = await createFixture(t);
  const response = await fetch(`${fixture.baseUrl}/api/v1/partner/me/config`, {
    headers: {
      authorization: `Bearer ${await fixture.token({ emailVerified: false })}`,
    },
  });

  assert.equal(response.status, 403);
  assert.equal((await response.json()).error.code, 'PARTNER_IDENTITY_REQUIRED');
  assert.equal(fixture.calls.length, 0);
});

test('allows partner read and write preflight only from configured portal origins', async (t) => {
  const fixture = await createFixture(t);
  for (const method of ['GET', 'POST', 'PATCH']) {
    const allowed = await fetch(`${fixture.baseUrl}/api/v1/partner/products`, {
      method: 'OPTIONS',
      headers: {
        origin: 'http://localhost:5173',
        'access-control-request-method': method,
        'access-control-request-headers': 'authorization,content-type',
      },
    });
    assert.equal(allowed.status, 204);
    assert.equal(allowed.headers.get('access-control-allow-origin'), 'http://localhost:5173');
    assert.equal(
      allowed.headers.get('access-control-allow-methods'),
      'GET, POST, PATCH, OPTIONS',
    );
  }

  const denied = await fetch(`${fixture.baseUrl}/api/v1/partner/me/config`, {
    method: 'OPTIONS',
    headers: { origin: 'https://unexpected.example.test' },
  });
  assert.equal(denied.status, 401);
  assert.equal(denied.headers.get('access-control-allow-origin'), null);
});
