const assert = require('node:assert/strict');
const test = require('node:test');
const {
  getPartnerTypeProfile,
  partnerTypeProfiles,
  validateProfileUnit,
} = require('../../src/modules/partner-types/profiles');

test('exports a profile with the required shape for each supported partner type', () => {
  assert.deepEqual(Object.keys(partnerTypeProfiles).sort(), [
    'bakery',
    'fruits_vegetables',
    'local_store',
    'meat',
    'restaurant',
  ]);

  for (const profile of Object.values(partnerTypeProfiles)) {
    assert.equal(typeof profile.label, 'string');
    assert.ok(Array.isArray(profile.allowedUnits));
    assert.ok(Array.isArray(profile.extraProductFields));
    assert.ok(Array.isArray(profile.defaultCategories));
    assert.deepEqual(
      Object.keys(profile.orderStatusLabels).sort(),
      ['accepted', 'preparing', 'ready'],
    );
    for (const field of profile.extraProductFields) {
      assert.equal(typeof field.key, 'string');
      assert.equal(typeof field.label, 'string');
      assert.ok(['text', 'boolean', 'select', 'number'].includes(field.type));
      assert.equal(typeof field.required, 'boolean');
      if (field.type === 'select') assert.ok(Array.isArray(field.options));
    }
    for (const category of profile.defaultCategories) {
      assert.equal(typeof category.name, 'string');
      assert.equal(typeof category.slug, 'string');
    }
  }
});

test('defines the requested product fields, units, and meat categories', () => {
  assert.deepEqual(partnerTypeProfiles.restaurant.allowedUnits, ['each', 'portion']);
  assert.deepEqual(partnerTypeProfiles.meat.allowedUnits, ['g', 'kg']);
  assert.deepEqual(partnerTypeProfiles.bakery.allowedUnits, ['each', 'g', 'kg']);
  assert.deepEqual(partnerTypeProfiles.fruits_vegetables.allowedUnits, [
    'g',
    'kg',
    'each',
    'bunch',
  ]);
  assert.deepEqual(partnerTypeProfiles.local_store.allowedUnits, [
    'g',
    'kg',
    'ml',
    'L',
    'each',
  ]);
  assert.deepEqual(
    partnerTypeProfiles.meat.defaultCategories.map((category) => category.name),
    ['Chicken', 'Mutton'],
  );
  assert.deepEqual(
    partnerTypeProfiles.bakery.extraProductFields.map((field) => field.key),
    ['eggless', 'shelfLifeDays'],
  );
  assert.deepEqual(
    partnerTypeProfiles.fruits_vegetables.extraProductFields.map((field) => field.key),
    ['organic', 'origin'],
  );
  assert.deepEqual(
    partnerTypeProfiles.restaurant.extraProductFields.map((field) => field.key),
    ['isVeg', 'prepTimeMinutes', 'spiceLevel'],
  );
  assert.deepEqual(
    partnerTypeProfiles.local_store.extraProductFields.map((field) => field.key),
    ['brand', 'mrpMinor'],
  );
});

test('validates profile units through the shared variant unit normalizer', () => {
  assert.deepEqual(validateProfileUnit('meat', ' KG '), {
    valid: true,
    normalizedUnit: 'kg',
  });
  assert.deepEqual(validateProfileUnit('local_store', 'l'), {
    valid: true,
    normalizedUnit: 'L',
  });
  assert.deepEqual(validateProfileUnit('meat', 'ml'), {
    valid: false,
    normalizedUnit: null,
  });
  assert.equal(getPartnerTypeProfile('unknown'), null);
});
