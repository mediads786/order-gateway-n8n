
BEGIN;

CREATE TABLE IF NOT EXISTS public.mock_erp_orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    external_reference text NOT NULL UNIQUE,
    payload jsonb NOT NULL,
    payload_hash text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT mock_erp_reference_not_blank
        CHECK (length(btrim(external_reference)) > 0)
);

CREATE OR REPLACE FUNCTION public.accept_mock_erp_order(
    p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_reference text;
    v_hash text;
    v_id uuid;
    v_existing public.mock_erp_orders%ROWTYPE;
BEGIN
    IF p_payload IS NULL
       OR jsonb_typeof(p_payload) <> 'object' THEN
        RETURN jsonb_build_object(
            'result', 'invalid',
            'error', 'invalid_payload'
        );
    END IF;

    v_reference := btrim(
        p_payload ->> 'external_reference'
    );

    IF v_reference IS NULL OR v_reference = '' THEN
        RETURN jsonb_build_object(
            'result', 'invalid',
            'error', 'missing_external_reference'
        );
    END IF;

    v_hash := md5(p_payload::text);

    -- Unique constraint ensures concurrent duplicates
    -- cannot create two ERP records.
    INSERT INTO public.mock_erp_orders (
        external_reference,
        payload,
        payload_hash
    )
    VALUES (
        v_reference,
        p_payload,
        v_hash
    )
    ON CONFLICT (external_reference) DO NOTHING
    RETURNING id INTO v_id;

    IF v_id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'result', 'created',
            'odoo_order_id', 'MOCK-' || v_id::text,
            'external_reference', v_reference
        );
    END IF;

    SELECT *
    INTO v_existing
    FROM public.mock_erp_orders
    WHERE external_reference = v_reference;

    IF v_existing.payload = p_payload THEN
        RETURN jsonb_build_object(
            'result', 'duplicate',
            'odoo_order_id',
                'MOCK-' || v_existing.id::text,
            'external_reference', v_reference
        );
    END IF;

    RETURN jsonb_build_object(
        'result', 'conflict',
        'error', 'external_reference_conflict',
        'external_reference', v_reference
    );
END;
$$;

REVOKE ALL ON TABLE public.mock_erp_orders
FROM PUBLIC;

REVOKE ALL ON FUNCTION public.accept_mock_erp_order(jsonb)
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.accept_mock_erp_order(jsonb)
TO gateway_app;

COMMIT;
