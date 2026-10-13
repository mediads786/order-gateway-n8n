
BEGIN;

-- 1. Canonical Shopify orders
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_domain TEXT NOT NULL,
    shopify_order_id TEXT NOT NULL,
    order_number TEXT,
    currency VARCHAR(3) NOT NULL,
    total_amount NUMERIC(18, 2) NOT NULL CHECK (total_amount >= 0),
    customer_data JSONB NOT NULL DEFAULT '{}'::jsonb,
    raw_order JSONB NOT NULL,
    order_status TEXT NOT NULL DEFAULT 'accepted'
        CHECK (order_status IN ('accepted', 'delivered', 'failed')),
    odoo_order_id TEXT,
    external_reference TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_shopify_order UNIQUE (shop_domain, shopify_order_id),
    CONSTRAINT chk_shop_domain CHECK (length(trim(shop_domain)) > 0)
);

-- 2. Order line items
CREATE TABLE order_lines (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id),
    shopify_line_id TEXT NOT NULL,
    sku TEXT NOT NULL,
    description TEXT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(18, 2) NOT NULL CHECK (unit_price >= 0),
    CONSTRAINT uq_order_line UNIQUE (order_id, shopify_line_id)
);

-- 3. Webhook receipt and deduplication history
CREATE TABLE webhook_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_domain TEXT NOT NULL,
    webhook_id TEXT NOT NULL,
    topic TEXT NOT NULL,
    payload_hash TEXT NOT NULL,
    order_id UUID REFERENCES orders(id),
    status TEXT NOT NULL DEFAULT 'received'
        CHECK (status IN ('received', 'accepted', 'duplicate', 'rejected', 'conflict')),
    error_message TEXT,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ,
    CONSTRAINT uq_webhook_delivery UNIQUE (shop_domain, webhook_id)
);

-- 4. Durable delivery queue
CREATE TABLE delivery_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL UNIQUE REFERENCES orders(id),
    status TEXT NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'processing', 'retry', 'succeeded', 'dead')),
    attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    max_attempts INTEGER NOT NULL DEFAULT 5 CHECK (max_attempts > 0),
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    locked_at TIMESTAMPTZ,
    lease_token UUID,
    last_error TEXT,
    error_category TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);

CREATE INDEX idx_delivery_jobs_ready
    ON delivery_jobs (next_attempt_at, created_at)
    WHERE status IN ('queued', 'retry');

CREATE INDEX idx_delivery_jobs_stale
    ON delivery_jobs (locked_at)
    WHERE status = 'processing';

-- 5. Processing and audit history
CREATE TABLE audit_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id UUID REFERENCES orders(id),
    job_id UUID REFERENCES delivery_jobs(id),
    webhook_receipt_id UUID REFERENCES webhook_receipts(id),
    event_type TEXT NOT NULL,
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_order
    ON audit_events (order_id, created_at);

CREATE INDEX idx_audit_job
    ON audit_events (job_id, created_at);

-- Prevent changes to existing audit events.
CREATE FUNCTION prevent_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Audit events are append-only';
END;
$$;

CREATE TRIGGER trg_audit_append_only
BEFORE UPDATE OR DELETE ON audit_events
FOR EACH ROW EXECUTE FUNCTION prevent_audit_mutation();

-- Restricted application access.
GRANT SELECT ON
    orders,
    order_lines,
    webhook_receipts,
    delivery_jobs,
    audit_events
TO gateway_app;

COMMIT;
