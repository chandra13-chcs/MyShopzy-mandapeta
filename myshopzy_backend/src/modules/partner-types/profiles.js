const { normalizeUnit } = require('../shared/variant-rules');

function freezeProfile(profile) {
  profile.allowedUnits = Object.freeze(profile.allowedUnits);
  profile.extraProductFields = Object.freeze(
    profile.extraProductFields.map((field) =>
      Object.freeze({
        ...field,
        ...(field.options ? { options: Object.freeze(field.options) } : {}),
      }),
    ),
  );
  profile.defaultCategories = Object.freeze(
    profile.defaultCategories.map((category) => Object.freeze(category)),
  );
  profile.orderStatusLabels = Object.freeze(profile.orderStatusLabels);
  return Object.freeze(profile);
}

const partnerTypeProfiles = Object.freeze({
  restaurant: freezeProfile({
    label: 'Restaurant',
    allowedUnits: ['each', 'portion'],
    extraProductFields: [
      { key: 'isVeg', label: 'Vegetarian', type: 'boolean', required: false },
      { key: 'prepTimeMinutes', label: 'Preparation time (minutes)', type: 'number', required: false },
      {
        key: 'spiceLevel',
        label: 'Spice level',
        type: 'select',
        required: false,
        options: ['mild', 'medium', 'hot'],
      },
    ],
    defaultCategories: [
      { name: 'Biryani', slug: 'biryani' },
      { name: 'Starters', slug: 'starters' },
      { name: 'Main Course', slug: 'main-course' },
      { name: 'Meals', slug: 'meals' },
      { name: 'Beverages', slug: 'beverages' },
      { name: 'Desserts', slug: 'desserts' },
    ],
    orderStatusLabels: {
      accepted: 'Order accepted',
      preparing: 'Preparing food',
      ready: 'Ready for pickup',
    },
  }),
  meat: freezeProfile({
    label: 'Meat',
    allowedUnits: ['g', 'kg'],
    extraProductFields: [
      {
        key: 'cutType',
        label: 'Cut type',
        type: 'select',
        required: true,
        options: ['curry_cut', 'boneless', 'mince', 'whole'],
      },
      {
        key: 'freshOrFrozen',
        label: 'Fresh or frozen',
        type: 'select',
        required: true,
        options: ['fresh', 'frozen'],
      },
    ],
    defaultCategories: [
      { name: 'Chicken', slug: 'chicken' },
      { name: 'Mutton', slug: 'mutton' },
    ],
    orderStatusLabels: {
      accepted: 'Order accepted',
      preparing: 'Preparing order',
      ready: 'Ready for pickup',
    },
  }),
  bakery: freezeProfile({
    label: 'Bakery',
    allowedUnits: ['each', 'g', 'kg'],
    extraProductFields: [
      { key: 'eggless', label: 'Eggless', type: 'boolean', required: false },
      { key: 'shelfLifeDays', label: 'Shelf life (days)', type: 'number', required: false },
    ],
    defaultCategories: [
      { name: 'Cakes', slug: 'cakes' },
      { name: 'Bread', slug: 'bread' },
      { name: 'Pastries', slug: 'pastries' },
      { name: 'Cookies', slug: 'cookies' },
    ],
    orderStatusLabels: {
      accepted: 'Order accepted',
      preparing: 'Preparing order',
      ready: 'Ready for pickup',
    },
  }),
  fruits_vegetables: freezeProfile({
    label: 'Fruits & Vegetables',
    allowedUnits: ['g', 'kg', 'each', 'bunch'],
    extraProductFields: [
      { key: 'organic', label: 'Organic', type: 'boolean', required: false },
      { key: 'origin', label: 'Origin', type: 'text', required: false },
    ],
    defaultCategories: [
      { name: 'Fruits', slug: 'fruits' },
      { name: 'Vegetables', slug: 'vegetables' },
      { name: 'Leafy Greens', slug: 'leafy-greens' },
      { name: 'Herbs', slug: 'herbs' },
    ],
    orderStatusLabels: {
      accepted: 'Order accepted',
      preparing: 'Packing order',
      ready: 'Ready for delivery',
    },
  }),
  local_store: freezeProfile({
    label: 'Local Store',
    allowedUnits: ['g', 'kg', 'ml', 'L', 'each'],
    extraProductFields: [
      { key: 'brand', label: 'Brand', type: 'text', required: false },
      { key: 'mrpMinor', label: 'MRP (minor currency units)', type: 'number', required: false },
    ],
    defaultCategories: [
      { name: 'Groceries', slug: 'groceries' },
      { name: 'Beverages', slug: 'beverages' },
      { name: 'Snacks', slug: 'snacks' },
      { name: 'Household', slug: 'household' },
      { name: 'Personal Care', slug: 'personal-care' },
      { name: 'Frozen Foods', slug: 'frozen-foods', categoryCode: 'frozen_foods' },
    ],
    orderStatusLabels: {
      accepted: 'Order accepted',
      preparing: 'Packing order',
      ready: 'Ready for pickup',
    },
  }),
});

function getPartnerTypeProfile(type) {
  return Object.hasOwn(partnerTypeProfiles, type)
    ? partnerTypeProfiles[type]
    : null;
}

function validateProfileUnit(type, unit) {
  const profile = getPartnerTypeProfile(type);
  const normalizedUnit = normalizeUnit(unit);
  if (!profile || !normalizedUnit || !profile.allowedUnits.includes(normalizedUnit)) {
    return { valid: false, normalizedUnit: null };
  }
  return { valid: true, normalizedUnit };
}

module.exports = {
  getPartnerTypeProfile,
  partnerTypeProfiles,
  validateProfileUnit,
};
