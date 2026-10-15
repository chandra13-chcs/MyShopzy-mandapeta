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
