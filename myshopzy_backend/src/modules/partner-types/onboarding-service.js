const { randomUUID } = require('node:crypto');
const { getPartnerTypeProfile } = require('./profiles');

function slugify(value) {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function requiredText(value, label) {
  if (typeof value !== 'string' || !value.trim()) {
    throw new TypeError(`${label} is required.`);
  }
  return value.trim();
}

async function createPartnerWithDefaults({
  databasePool,
  name,
  type,
  ownerEmail,
  ownerPhone,
  shop,
}) {
  if (!databasePool || typeof databasePool.connect !== 'function') {
    throw new TypeError('A PostgreSQL database pool is required.');
  }
  const partnerName = requiredText(name, 'Partner name');
  const email = requiredText(ownerEmail, 'Owner email').toLowerCase();
  const phone = requiredText(ownerPhone, 'Owner phone');
  if (!shop || typeof shop !== 'object' || Array.isArray(shop)) {
    throw new TypeError('Shop details are required.');
  }
  const shopName = requiredText(shop?.name, 'Shop name');
  const profile = getPartnerTypeProfile(type);
  if (!profile) throw new TypeError(`Unsupported partner type: ${type}.`);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new TypeError('Owner email must be a valid email address.');
  }
  if (shop.address !== undefined &&
      (!shop.address || typeof shop.address !== 'object' || Array.isArray(shop.address))) {
    throw new TypeError('Shop address must be an object.');
  }
  const shopLatitude = shop.address?.latitude ?? null;
  const shopLongitude = shop.address?.longitude ?? null;
  if (
    (shopLatitude === null) !== (shopLongitude === null) ||
    (shopLatitude !== null &&
      (typeof shopLatitude !== 'number' ||
        !Number.isFinite(shopLatitude) ||
        shopLatitude < -90 ||
        shopLatitude > 90 ||
        typeof shopLongitude !== 'number' ||
        !Number.isFinite(shopLongitude) ||
        shopLongitude < -180 ||
        shopLongitude > 180))
  ) {
    throw new TypeError('Shop address coordinates must be a valid latitude/longitude pair.');
  }
  if (shop.operatingDetails !== undefined &&
      (!shop.operatingDetails ||
        typeof shop.operatingDetails !== 'object' ||
        Array.isArray(shop.operatingDetails))) {
    throw new TypeError('Shop operating details must be an object.');
  }

  const client = await databasePool.connect();
  let transactionStarted = false;
  try {
    await client.query('BEGIN');
    transactionStarted = true;

    const partnerId = randomUUID();
    const shopId = randomUUID();
    const partnerSlug = `${slugify(partnerName) || 'partner'}-${partnerId.slice(0, 8)}`;
    const shopSlug = `${slugify(shopName) || 'shop'}-${shopId.slice(0, 8)}`;

    await client.query(
      `INSERT INTO app.partners (
         id, partner_type, status, name, slug, contact_email, contact_phone
       )
       VALUES ($1::uuid, $2, 'pending', $3, $4, $5, $6)`,
      [partnerId, type, partnerName, partnerSlug, email, phone],
    );

    const existingUserResult = await client.query(
      `SELECT id, status
       FROM app.users
       WHERE lower(email) = lower($1)
       LIMIT 2
       FOR UPDATE`,
      [email],
    );
    if (existingUserResult.rows.length > 1) {
      throw new Error('Multiple user records match the owner email.');
    }

    let userId;
    if (existingUserResult.rows.length === 1) {
      const existingUser = existingUserResult.rows[0];
      if (existingUser.status !== 'active') {
        throw new Error('The existing owner account is not active.');
      }
      userId = existingUser.id;
    } else {
      userId = randomUUID();
      await client.query(
        `INSERT INTO app.users (id, email, phone, display_name, system_role, status)
         VALUES ($1::uuid, $2, $3, 'Partner owner', 'customer', 'active')`,
        [userId, email, phone],
      );
    }

    await client.query(
      `INSERT INTO app.partner_memberships (
         partner_id, user_id, role, status
       )
       VALUES ($1::uuid, $2::uuid, 'owner', 'active')`,
      [partnerId, userId],
    );

    await client.query(
      `INSERT INTO app.shops (
         id, partner_id, name, slug, status, address, operating_details,
         latitude, longitude
       )
       VALUES ($1::uuid, $2::uuid, $3, $4, 'pending', $5::jsonb, $6::jsonb, $7, $8)`,
      [
        shopId,
        partnerId,
        shopName,
        shopSlug,
        JSON.stringify(shop.address ?? {}),
        JSON.stringify(shop.operatingDetails ?? {}),
        shopLatitude,
        shopLongitude,
      ],
    );

    const categories = [];
    for (const [index, category] of profile.defaultCategories.entries()) {
      const categoryId = randomUUID();
      await client.query(
        `INSERT INTO app.categories (
           id, partner_id, shop_id, name, slug, category_code, sort_order
         )
         VALUES ($1::uuid, $2::uuid, $3::uuid, $4, $5, $6, $7)`,
        [
          categoryId,
          partnerId,
          shopId,
          category.name,
          category.slug,
          category.categoryCode ?? null,
          index,
        ],
      );
      categories.push({ id: categoryId, name: category.name, slug: category.slug });
    }

    await client.query('COMMIT');
    return {
      partner: { id: partnerId, name: partnerName, type, slug: partnerSlug },
      user: { id: userId, email },
      shop: { id: shopId, name: shopName, slug: shopSlug },
      categories,
    };
  } catch (error) {
    if (transactionStarted) {
      try {
        await client.query('ROLLBACK');
      } catch (rollbackError) {
        throw new AggregateError(
          [error, rollbackError],
          'Partner onboarding failed and the transaction rollback also failed.',
        );
      }
    }
    throw error;
  } finally {
    client.release();
  }
}

module.exports = { createPartnerWithDefaults };
