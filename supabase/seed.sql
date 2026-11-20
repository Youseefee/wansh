-- ============================================================================
-- Wenshy (ونشي) - Seed Data: Winch Types Catalog
-- ============================================================================

INSERT INTO public.winch_types (
  code,
  name_ar,
  name_en,
  description_ar,
  description_en,
  base_fare,
  price_per_km,
  minimum_fare,
  road_factor,
  surge_multiplier,
  max_weight_tons,
  icon_name,
  sort_order,
  is_active
)
VALUES
  (
    'flatbed',
    'ونش سطحة',
    'Flatbed Tow Truck',
    'سطحة مسطحة كاملة لحمل السيارات الحديثة والدفع الرباعي بأمان دون سحب العجلات',
    'Full flatbed carrier ideal for modern sedans, EVs, and AWD/4x4 vehicles',
    300.00,
    22.00,
    450.00,
    1.25,
    1.00,
    4.50,
    'tow_flatbed',
    1,
    true
  ),
  (
    'hydraulic',
    'ونش هيدروليك (منزلق)',
    'Hydraulic Slide-Bed',
    'سطحة هيدروليك بزاوية تحميل منخفضة للسيارات الرياضية والمنخفضة والحوادث',
    'Low-angle hydraulic rollback carrier for sports cars, luxury, and accident recovery',
    400.00,
    28.00,
    600.00,
    1.25,
    1.00,
    5.00,
    'tow_hydraulic',
    2,
    true
  ),
  (
    'wheel_lift',
    'ونش جر (شوكة)',
    'Wheel-Lift Tow Truck',
    'ونش سريع ومرن لرفع المحور الأمامي أو الخلفي وسحب السيارات داخل الشوارع الضيقة',
    'Agile wheel-lift tow truck suitable for tight city streets and standard sedans',
    200.00,
    16.00,
    300.00,
    1.25,
    1.00,
    3.00,
    'tow_wheel_lift',
    3,
    true
  ),
  (
    'heavy_duty',
    'ونش نقل ثقيل',
    'Heavy-Duty Recovery',
    'ونش مخصص لسيارات النقل الخفيف والفان والسيارات كبيرة الحجم',
    'Heavy recovery tow truck for vans, pickup trucks, and commercial vehicles',
    550.00,
    38.00,
    850.00,
    1.30,
    1.00,
    12.00,
    'tow_heavy',
    4,
    true
  )
ON CONFLICT (code) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  description_ar = EXCLUDED.description_ar,
  description_en = EXCLUDED.description_en,
  base_fare = EXCLUDED.base_fare,
  price_per_km = EXCLUDED.price_per_km,
  minimum_fare = EXCLUDED.minimum_fare,
  road_factor = EXCLUDED.road_factor,
  max_weight_tons = EXCLUDED.max_weight_tons,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;
