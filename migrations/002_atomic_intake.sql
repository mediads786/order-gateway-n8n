
BEGIN;

CREATE OR REPLACE FUNCTION public.accept_shopify_order(
    p_shop_domain TEXT,
    p_webhook_id TEXT,
    p_topic TEXT,
    p_payload_hash TEXT,
    p_order JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_shop TEXT;
    v_order_id TEXT;
    v_order UUID;
    v_job UUID;
    v_receipt UUID;
    v_existing_hash TEXT;
    v_existing_payload JSONB;
    v_line JSONB;
    v_lines JSONB;
    v_ref TEXT;
BEGIN
    -- Validate identifiers and supported event.
    v_shop := lower(trim(p_shop_domain));
    v_order_id := trim(p_order->>'id');

    IF v_shop IS NULL OR v_shop = ''
       OR p_webhook_id IS NULL OR trim(p_webhook_id) = ''
       OR p_payload_hash IS NULL OR trim(p_payload_hash) = ''
       OR p_topic IS DISTINCT FROM 'orders/create'
       OR v_order_id IS NULL OR v_order_id = ''
    THEN
        RAISE EXCEPTION 'Invalid Shopify intake identifiers';
    END IF;

    IF jsonb_typeof(p_order) IS DISTINCT FROM 'object'
       OR jsonb_typeof(p_order->'line_items') IS DISTINCT FROM 'array'
       OR jsonb_array_length(p_order->'line_items') = 0
       OR length(trim(coalesce(p_order->>'currency', ''))) <> 3
       OR p_order->>'total_price' IS NULL
    THEN
        RAISE EXCEPTION 'Invalid Shopify order payload';
    END IF;

    v_lines := p_order->'line_items';

    -- Serialize submissions for the same Shopify order.
    -- Unique constraints remain the final integrity guard.
    PERFORM pg_advisory_xact_lock(
        hashtextextended(v_shop || ':' || v_order_id, 0)
    );

    -- Same webhook delivery ID already received?
    SELECT r.payload_hash, r.order_id
    INTO v_existing_hash, v_order
    FROM public.webhook_receipts r
    WHERE r.shop_domain = v_shop
      AND r.webhook_id = p_webhook_id;

    IF FOUND THEN
        IF v_existing_hash = p_payload_hash THEN
            RETURN jsonb_build_object(
                'result', 'duplicate',
                'reason', 'webhook_replay',
                'order_id', v_order
            );
        END IF;

        RETURN jsonb_build_object(
            'result', 'conflict',
            'reason', 'webhook_id_payload_mismatch'
        );
    END IF;

    -- Has this Shopify order already been accepted?
    SELECT o.id, o.raw_order
    INTO v_order, v_existing_payload
    FROM public.orders o
    WHERE o.shop_domain = v_shop
      AND o.shopify_order_id = v_order_id;

    IF FOUND THEN
        IF v_existing_payload = p_order THEN
            INSERT INTO public.webhook_receipts (
                shop_domain, webhook_id, topic,
                payload_hash, order_id, status, processed_at
            )
            VALUES (
                v_shop, p_webhook_id, p_topic,
                p_payload_hash, v_order, 'duplicate', now()
            )
            RETURNING id INTO v_receipt;

            INSERT INTO public.audit_events (
                order_id, webhook_receipt_id, event_type, details
            )
            VALUES (
                v_order, v_receipt, 'order_duplicate',
                jsonb_build_object('reason', 'existing_order')
            );

            RETURN jsonb_build_object(
                'result', 'duplicate',
                'reason', 'existing_order',
                'order_id', v_order
            );
        END IF;

        INSERT INTO public.webhook_receipts (
            shop_domain, webhook_id, topic,
            payload_hash, order_id, status,
            error_message, processed_at
        )
        VALUES (
            v_shop, p_webhook_id, p_topic,
            p_payload_hash, v_order, 'conflict',
            'Shopify order already exists with different payload',
            now()
        )
        RETURNING id INTO v_receipt;

        INSERT INTO public.audit_events (
            order_id, webhook_receipt_id, event_type, details
        )
        VALUES (
            v_order, v_receipt, 'order_conflict',
            jsonb_build_object('reason', 'changed_payload')
        );

        RETURN jsonb_build_object(
            'result', 'conflict',
            'reason', 'changed_order_payload',
            'order_id', v_order
        );
    END IF;

    -- New order: persist its canonical record.
    v_ref := 'shopify:' || v_shop || ':' || v_order_id;

    INSERT INTO public.orders (
        shop_domain, shopify_order_id, order_number,
        currency, total_amount, customer_data,
        raw_order, external_reference
    )
    VALUES (
        v_shop,
        v_order_id,
        p_order->>'name',
        upper(p_order->>'currency'),
        (p_order->>'total_price')::numeric(18,2),
        CASE
            WHEN jsonb_typeof(p_order->'customer') = 'object'
            THEN p_order->'customer'
            ELSE '{}'::jsonb
        END,
        p_order,
        v_ref
    )
    RETURNING id INTO v_order;

    -- Persist all lines. Invalid lines roll back everything.
    FOR v_line IN SELECT value FROM jsonb_array_elements(v_lines)
    LOOP
        IF jsonb_typeof(v_line) IS DISTINCT FROM 'object'
           OR nullif(trim(coalesce(v_line->>'id', '')), '') IS NULL
           OR nullif(trim(coalesce(v_line->>'sku', '')), '') IS NULL
           OR nullif(trim(coalesce(v_line->>'quantity', '')), '') IS NULL
           OR nullif(trim(coalesce(v_line->>'price', '')), '') IS NULL
        THEN
            RAISE EXCEPTION 'Invalid Shopify line item';
        END IF;

        INSERT INTO public.order_lines (
            order_id, shopify_line_id, sku,
            description, quantity, unit_price
        )
        VALUES (
            v_order,
            v_line->>'id',
            v_line->>'sku',
            v_line->>'title',
            (v_line->>'quantity')::integer,
            (v_line->>'price')::numeric(18,2)
        );
    END LOOP;

    -- Exactly one durable job per order.
    INSERT INTO public.delivery_jobs (order_id)
    VALUES (v_order)
    RETURNING id INTO v_job;

    INSERT INTO public.webhook_receipts (
        shop_domain, webhook_id, topic,
        payload_hash, order_id, status, processed_at
    )
    VALUES (
        v_shop, p_webhook_id, p_topic,
        p_payload_hash, v_order, 'accepted', now()
    )
    RETURNING id INTO v_receipt;

    INSERT INTO public.audit_events (
        order_id, job_id, webhook_receipt_id,
        event_type, details
    )
    VALUES (
        v_order, v_job, v_receipt,
        'order_accepted',
        jsonb_build_object(
            'shopify_order_id', v_order_id,
            'external_reference', v_ref
        )
    );

    RETURN jsonb_build_object(
        'result', 'accepted',
        'order_id', v_order,
        'job_id', v_job,
        'external_reference', v_ref
    );
END;
$$;

-- Restrict function execution.
REVOKE ALL ON FUNCTION public.accept_shopify_order(
    TEXT, TEXT, TEXT, TEXT, JSONB
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.accept_shopify_order(
    TEXT, TEXT, TEXT, TEXT, JSONB
) TO gateway_app;

COMMIT;
