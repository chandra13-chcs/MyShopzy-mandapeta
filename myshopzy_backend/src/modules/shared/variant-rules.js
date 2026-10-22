const ALLOWED_UNITS_BY_CATEGORY_CODE = Object.freeze({
  meat: Object.freeze(['g', 'kg']),
  produce: Object.freeze(['g', 'kg', 'each', 'bunch']),
  atta_rice_dal: Object.freeze(['g', 'kg']),
  oils: Object.freeze(['ml', 'L']),
  dairy: Object.freeze(['ml', 'L', 'each']),
  bakery: Object.freeze(['each', 'g', 'kg']),
});

const VARIANT_LIMITS = Object.freeze({
  maxVariantsPerProduct: 8,
  maxLabelLength: 20,
  maxProductNameLength: 80,
});

function normalizeUnit(unit) {
  if (typeof unit !== 'string') return null;
  const normalized = unit.trim().toLowerCase();
  if (!normalized) return null;
  return normalized === 'l' ? 'L' : normalized;
}

function validateProductName(name) {
  const errors = [];
  if (typeof name !== 'string' || name.trim().length === 0) {
    errors.push('Product name is required.');
  } else if (name.trim().length > VARIANT_LIMITS.maxProductNameLength) {
    errors.push(
      `Product name must be at most ${VARIANT_LIMITS.maxProductNameLength} characters.`,
    );
  }
  return { valid: errors.length === 0, errors };
}

function validateVariant(variant, categoryCode) {
  const allowedUnits = Object.hasOwn(
    ALLOWED_UNITS_BY_CATEGORY_CODE,
    categoryCode,
  )
    ? ALLOWED_UNITS_BY_CATEGORY_CODE[categoryCode]
    : null;
  if (!allowedUnits) {
    return {
      valid: false,
      errors: [`Unknown category code: ${categoryCode}.`],
    };
  }
  return validateVariantWithAllowedUnits(variant, allowedUnits);
}

function validateVariantWithAllowedUnits(variant, allowedUnits) {
  const errors = [];
  if (!variant || typeof variant !== 'object' || Array.isArray(variant)) {
    errors.push('Variant must be an object.');
    return { valid: false, errors };
  }

  if (typeof variant.label !== 'string' || variant.label.trim().length === 0) {
    errors.push('Variant label is required.');
  } else if (variant.label.trim().length > VARIANT_LIMITS.maxLabelLength) {
    errors.push(
      `Variant label must be at most ${VARIANT_LIMITS.maxLabelLength} characters.`,
    );
  }

  const unit = normalizeUnit(variant.unit);
  if (unit === null) {
    errors.push('Variant unit is required.');
  } else if (allowedUnits && !allowedUnits.includes(unit)) {
    errors.push(`Unit ${unit} is not allowed for this product type.`);
  }
  if (
    typeof variant.quantity !== 'number' ||
    !Number.isFinite(variant.quantity) ||
    variant.quantity <= 0
  ) {
    errors.push('Variant quantity must be a positive number.');
  }
  if (!Number.isSafeInteger(variant.price_minor) || variant.price_minor < 0) {
    errors.push('Variant price_minor must be a non-negative safe integer.');
  }
  if (
    variant.stock !== null &&
    (!Number.isSafeInteger(variant.stock) || variant.stock < 0)
  ) {
    errors.push('Variant stock must be null or a non-negative integer.');
  }
  if (typeof variant.is_available !== 'boolean') {
    errors.push('Variant is_available must be a boolean.');
  }
  if (
    variant.sort_order !== undefined &&
    (!Number.isSafeInteger(variant.sort_order) || variant.sort_order < 0)
  ) {
    errors.push('Variant sort_order must be a non-negative integer.');
  }
  if (
    variant.sku !== undefined &&
    variant.sku !== null &&
    (typeof variant.sku !== 'string' || variant.sku.trim().length === 0)
  ) {
    errors.push('Variant SKU must be a non-empty string or null.');
  }

  return {
    valid: errors.length === 0,
    errors,
    ...(unit === null ? {} : { normalizedUnit: unit }),
  };
}

function validateVariants(variants, categoryCode) {
  const errors = [];
  if (!Array.isArray(variants)) {
    return { valid: false, errors: ['Variants must be an array.'] };
  }
  if (variants.length === 0) {
    errors.push('A product must have at least one variant.');
  }
  if (variants.length > VARIANT_LIMITS.maxVariantsPerProduct) {
    errors.push(
      `A product may have at most ${VARIANT_LIMITS.maxVariantsPerProduct} variants.`,
    );
  }
  variants.forEach((variant, index) => {
    const result = validateVariant(variant, categoryCode);
    errors.push(...result.errors.map((error) => `Variant ${index + 1}: ${error}`));
  });
  return { valid: errors.length === 0, errors };
}

module.exports = {
  ALLOWED_UNITS_BY_CATEGORY_CODE,
  VARIANT_LIMITS,
  normalizeUnit,
  validateProductName,
  validateVariant,
  validateVariantWithAllowedUnits,
  validateVariants,
};
