
BEGIN;

CREATE OR REPLACE FUNCTION public.record_rejected_webhook(
    p_shop_domain TEXT,
    p_webhook_id TEXT,
    p_topic TEXT,
    p_payload_hash TEXT,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_shop TEXT;
    v_webhook TEXT;
    v_receipt UUID;
    v_existing_hash TEXT;
    v_existing_status TEXT;
BEGIN
    v_shop := lower(trim(p_shop_domain));
    v_webhook := trim(p_webhook_id);

    IF nullif(v_shop, '') IS NULL
       OR nullif(v_webhook, '') IS NULL
       OR nullif(trim(p_topic), '') IS NULL
       OR p_payload_hash !~ '^[0-9a-f]{64}$'
       OR nullif(trim(p_reason), '') IS NULL
    THEN
        RAISE EXCEPTION 'Invalid rejection audit parameters';
    END IF;

    -- Serialize operations for this webhook delivery ID.
    PERFORM pg_advisory_xact_lock(
        hashtextextended(
            'webhook:' || v_shop || ':' || v_webhook, 0
        )
    );

    SELECT payload_hash, status
      INTO v_existing_hash, v_existing_status
    FROM public.webhook_receipts
    WHERE shop_domain = v_shop
      AND webhook_id = v_webhook;

    IF FOUND THEN
        IF v_existing_hash = p_payload_hash THEN
            RETURN jsonb_build_object(
                'result', 'duplicate',
                'receipt_status', v_existing_status
            );
        END IF;

        RETURN jsonb_build_object(
            'result', 'conflict',
            'reason', 'webhook_id_payload_mismatch'
        );
    END IF;

    INSERT INTO public.webhook_receipts (
        shop_domain,
        webhook_id,
        topic,
        payload_hash,
        status,
        error_message,
        processed_at
    )
    VALUES (
        v_shop,
        v_webhook,
        p_topic,
        p_payload_hash,
        'rejected',
        left(p_reason, 1000),
        now()
    )
    RETURNING id INTO v_receipt;

    INSERT INTO public.audit_events (
        webhook_receipt_id,
        event_type,
        details
    )
    VALUES (
        v_receipt,
        'order_rejected',
        jsonb_build_object(
            'reason', left(p_reason, 1000),
            'shop_domain', v_shop,
            'topic', p_topic
        )
    );

    RETURN jsonb_build_object(
        'result', 'rejected',
        'receipt_id', v_receipt
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_rejected_webhook(
    TEXT, TEXT, TEXT, TEXT, TEXT
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.record_rejected_webhook(
    TEXT, TEXT, TEXT, TEXT, TEXT
) TO gateway_app;

COMMIT;
