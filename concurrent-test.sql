SET ROLE gateway_app;
SELECT public.accept_shopify_order(
    'test-store.myshopify.com',
    'test-webhook-concurrent-001',
    'orders/create',
    '182a7518ee329088c32c836583491b7e5bdbcbe4d6280d56e0edbbeb27bdca43',
    '{
  "id": 100003,
  "name": "#1001",
  "currency": "USD",
  "total_price": "59.98",
  "customer": {
    "id": 5001,
    "email": "test@example.com"
  },
  "line_items": [
    {
      "id": 200001,
      "sku": "TEST-SKU-001",
      "title": "Test Product",
      "quantity": 2,
      "price": "29.99"
    }
  ]
}
'::jsonb
);
