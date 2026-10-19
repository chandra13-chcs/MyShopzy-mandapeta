INSERT INTO app.users (
  id, email, display_name, system_role, status
) VALUES (
  '00000000-0000-4000-8000-000000000001',
  'demo-rider@myshopzy.local',
  'Demo Rider',
  'rider',
  'active'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO app.riders (user_id, status)
VALUES ('00000000-0000-4000-8000-000000000001', 'active')
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO app.partners (
  id, partner_type, status, name, slug
) VALUES
  (
    '10000000-0000-4000-8000-000000000001',
    'restaurant',
    'approved',
    'Mandapeta Kitchen',
    'mandapeta-kitchen'
  ),
  (
    '10000000-0000-4000-8000-000000000002',
    'grocery',
    'approved',
    'Green Basket',
    'green-basket'
  )
ON CONFLICT DO NOTHING;

INSERT INTO app.shops (
  id, partner_id, name, slug, status, address
) VALUES
  (
    '20000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'Mandapeta Kitchen',
    'main',
    'active',
    '{"locality":"Mandapeta"}'::jsonb
  ),
  (
    '20000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',
    'Green Basket',
    'main',
    'active',
    '{"locality":"Mandapeta"}'::jsonb
  )
ON CONFLICT DO NOTHING;

INSERT INTO app.categories (
  id, partner_id, shop_id, name, slug, sort_order
) VALUES
  (
    '30000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    'Biryani',
    'biryani',
    1
  ),
  (
    '30000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    'Curries',
    'curries',
    2
  ),
  (
    '30000000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000002',
    'Fresh Produce',
    'fresh-produce',
    1
  )
ON CONFLICT DO NOTHING;

INSERT INTO app.products (
  id, partner_id, shop_id, category_id, sku, name, description,
  price_minor, currency, inventory_quantity, is_available, status
) VALUES
  (
    '40000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    'MK-BIR-001',
    'Chicken Biryani',
    'Aromatic chicken biryani.',
    24900,
    'INR',
    30,
    true,
    'active'
  ),
  (
    '40000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    'MK-BIR-002',
    'Veg Biryani',
    'Fragrant vegetable biryani.',
    18900,
    'INR',
    25,
    true,
    'active'
  ),
  (
    '40000000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000001',
    'MK-BIR-003',
    'Paneer Biryani',
    'Biryani with paneer and spices.',
    21900,
    'INR',
    20,
    true,
    'active'
  ),
  (
    '40000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000002',
    'MK-CUR-001',
    'Butter Chicken',
    'Creamy tomato-based chicken curry.',
    27900,
    'INR',
    18,
    true,
    'active'
  ),
  (
    '40000000-0000-4000-8000-000000000005',
    '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001',
    '30000000-0000-4000-8000-000000000002',
    'MK-CUR-002',
    'Paneer Butter Masala',
    'Paneer in a rich tomato gravy.',
    23900,
    'INR',
    20,
    true,
    'active'
  ),
  (
    '40000000-0000-4000-8000-000000000006',
    '10000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000002',
    '30000000-0000-4000-8000-000000000003',
    'GB-FRU-001',
    'Bananas',
    'Fresh bananas, sold per dozen.',
    6000,
    'INR',
    40,
    true,
    'active'
  ),
  (
    '40000000-0000-4000-8000-000000000007',
    '10000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000002',
    '30000000-0000-4000-8000-000000000003',
    'GB-FRU-002',
    'Apples',
    'Crisp apples, sold per kilogram.',
    16000,
    'INR',
    25,
    true,
    'active'
  ),
  (
    '40000000-0000-4000-8000-000000000008',
    '10000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000002',
    '30000000-0000-4000-8000-000000000003',
    'GB-VEG-001',
    'Tomatoes',
    'Fresh tomatoes, sold per kilogram.',
    4000,
    'INR',
    35,
    true,
    'active'
  ),
  (
    '40000000-0000-4000-8000-000000000009',
    '10000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000002',
    '30000000-0000-4000-8000-000000000003',
    'GB-VEG-002',
    'Potatoes',
    'Fresh potatoes, sold per kilogram.',
    3000,
    'INR',
    50,
    true,
    'active'
  ),
  (
    '40000000-0000-4000-8000-000000000010',
    '10000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000002',
    '30000000-0000-4000-8000-000000000003',
    'GB-VEG-003',
    'Spinach',
    'Fresh spinach bunch.',
    2500,
    'INR',
    30,
    true,
    'active'
  )
ON CONFLICT DO NOTHING;

INSERT INTO app.product_variants (
  product_id,
  partner_id,
  shop_id,
  label,
  unit,
  quantity,
  price_minor,
  stock,
  sku,
  is_available,
  sort_order
)
SELECT
  p.id,
  p.partner_id,
  p.shop_id,
  seeded.label,
  seeded.unit,
  seeded.quantity,
  seeded.price_minor,
  seeded.stock,
  seeded.sku,
  true,
  seeded.sort_order
FROM (
  VALUES
    ('40000000-0000-4000-8000-000000000001'::uuid, '1 serving', 'each', 1::numeric, 24900::bigint, 30, 'MK-BIR-001-S1', 1),
    ('40000000-0000-4000-8000-000000000001'::uuid, '2 servings', 'each', 2::numeric, 44900::bigint, 15, 'MK-BIR-001-S2', 2),
    ('40000000-0000-4000-8000-000000000002'::uuid, '1 serving', 'each', 1::numeric, 18900::bigint, 25, 'MK-BIR-002-S1', 1),
    ('40000000-0000-4000-8000-000000000002'::uuid, '2 servings', 'each', 2::numeric, 34900::bigint, 12, 'MK-BIR-002-S2', 2),
    ('40000000-0000-4000-8000-000000000003'::uuid, '1 serving', 'each', 1::numeric, 21900::bigint, 20, 'MK-BIR-003-S1', 1),
    ('40000000-0000-4000-8000-000000000003'::uuid, '2 servings', 'each', 2::numeric, 39900::bigint, 10, 'MK-BIR-003-S2', 2),
    ('40000000-0000-4000-8000-000000000004'::uuid, '1 serving', 'each', 1::numeric, 27900::bigint, 18, 'MK-CUR-001-S1', 1),
    ('40000000-0000-4000-8000-000000000004'::uuid, '2 servings', 'each', 2::numeric, 49900::bigint, 9, 'MK-CUR-001-S2', 2),
    ('40000000-0000-4000-8000-000000000005'::uuid, '1 serving', 'each', 1::numeric, 23900::bigint, 20, 'MK-CUR-002-S1', 1),
    ('40000000-0000-4000-8000-000000000005'::uuid, '2 servings', 'each', 2::numeric, 42900::bigint, 10, 'MK-CUR-002-S2', 2),
    ('40000000-0000-4000-8000-000000000006'::uuid, '6 each', 'each', 6::numeric, 3500::bigint, 40, 'GB-FRU-001-6', 1),
    ('40000000-0000-4000-8000-000000000006'::uuid, '12 each', 'each', 12::numeric, 6000::bigint, 20, 'GB-FRU-001-12', 2),
    ('40000000-0000-4000-8000-000000000007'::uuid, '500 g', 'g', 500::numeric, 8000::bigint, 25, 'GB-FRU-002-500G', 1),
    ('40000000-0000-4000-8000-000000000007'::uuid, '1 kg', 'kg', 1::numeric, 16000::bigint, 25, 'GB-FRU-002-1KG', 2),
    ('40000000-0000-4000-8000-000000000008'::uuid, '500 g', 'g', 500::numeric, 2500::bigint, 35, 'GB-VEG-001-500G', 1),
    ('40000000-0000-4000-8000-000000000008'::uuid, '1 kg', 'kg', 1::numeric, 4000::bigint, 35, 'GB-VEG-001-1KG', 2),
    ('40000000-0000-4000-8000-000000000009'::uuid, '1 kg', 'kg', 1::numeric, 3000::bigint, 50, 'GB-VEG-002-1KG', 1),
    ('40000000-0000-4000-8000-000000000009'::uuid, '5 kg', 'kg', 5::numeric, 13500::bigint, 10, 'GB-VEG-002-5KG', 2),
    ('40000000-0000-4000-8000-000000000010'::uuid, '1 bunch', 'bunch', 1::numeric, 2500::bigint, 30, 'GB-VEG-003-1B', 1),
    ('40000000-0000-4000-8000-000000000010'::uuid, '2 bunches', 'bunch', 2::numeric, 4500::bigint, 15, 'GB-VEG-003-2B', 2)
) AS seeded (
  product_id,
  label,
  unit,
  quantity,
  price_minor,
  stock,
  sku,
  sort_order
)
JOIN app.products AS p ON p.id = seeded.product_id
ON CONFLICT DO NOTHING;
