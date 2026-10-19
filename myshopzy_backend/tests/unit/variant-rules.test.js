const assert = require('node:assert/strict');
const test = require('node:test');

const {
  ALLOWED_UNITS_BY_CATEGORY_CODE,
  VARIANT_LIMITS,
  normalizeUnit,
  validateProductName,
  validateVariant,
  validateVariants,
} = require('../../src/modules/shared/variant-rules');

function variant(overrides = {}) {
  return {
    label: '500 g',
    unit: 'g',
    quantity: 500,
    price_minor: 12500,
    stock: 10,
    sku: null,
    is_available: true,
    sort_order: 0,
    ...overrides,
  };
}

test('defines the requested allowed units per category code', () => {
  assert.deepEqual(ALLOWED_UNITS_BY_CATEGORY_CODE, {
    meat: ['g', 'kg'],
    produce: ['g', 'kg', 'each', 'bunch'],
    atta_rice_dal: ['g', 'kg'],
    oils: ['ml', 'L'],
    dairy: ['ml', 'L', 'each'],
    bakery: ['each', 'g', 'kg'],
  });
});

test('normalizes unit case and whitespace', () => {
  assert.equal(normalizeUnit(' KG '), 'kg');
  assert.equal(normalizeUnit('ml'), 'ml');
  assert.equal(normalizeUnit('l'), 'L');
  assert.equal(normalizeUnit('  '), null);
  assert.equal(normalizeUnit(null), null);
});

test('accepts a valid variant and rejects invalid or unknown units/categories', () => {
  assert.deepEqual(validateVariant(variant(), 'meat'), {
    valid: true,
    errors: [],
    normalizedUnit: 'g',
  });
  assert.equal(validateVariant(variant({ unit: 'ml' }), 'meat').valid, false);
  assert.match(
    validateVariant(variant(), 'unknown_category').errors.join(' '),
    /Unknown category code/,
  );
  assert.match(
    validateVariant(variant(), 'toString').errors.join(' '),
    /Unknown category code/,
  );
});

test('enforces variant labels, positive quantity, non-negative price and stock', () => {
  assert.equal(
    validateVariant(variant({ label: 'a'.repeat(21) }), 'meat').valid,
    false,
  );
  assert.equal(validateVariant(variant({ quantity: 0 }), 'meat').valid, false);
  assert.equal(validateVariant(variant({ price_minor: -1 }), 'meat').valid, false);
  assert.equal(validateVariant(variant({ stock: -1 }), 'meat').valid, false);
  assert.equal(validateVariant(variant({ stock: null }), 'meat').valid, true);
  assert.equal(VARIANT_LIMITS.maxLabelLength, 20);
});

test('enforces product name and maximum variants per product', () => {
  assert.equal(validateProductName('Good product').valid, true);
  assert.equal(validateProductName(' ').valid, false);
  assert.equal(validateProductName('a'.repeat(81)).valid, false);
  assert.equal(VARIANT_LIMITS.maxProductNameLength, 80);
  assert.equal(
    validateVariants(Array.from({ length: 8 }, () => variant()), 'meat').valid,
    true,
  );
  assert.equal(
    validateVariants(Array.from({ length: 9 }, () => variant()), 'meat').valid,
    false,
  );
  assert.equal(validateVariants([], 'meat').valid, false);
  assert.equal(VARIANT_LIMITS.maxVariantsPerProduct, 8);
});
