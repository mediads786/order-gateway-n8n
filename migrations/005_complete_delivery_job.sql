
BEGIN;

CREATE OR REPLACE FUNCTION public.complete_delivery_job(
    p_job_id uuid,
    p_lease_token uuid,
    p_odoo_order_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_job public.delivery_jobs%ROWTYPE;
    v_odoo_order_id text;
BEGIN
    v_odoo_order_id := btrim(p_odoo_order_id);

    IF p_job_id IS NULL
       OR p_lease_token IS NULL
       OR v_odoo_order_id IS NULL
       OR v_odoo_order_id = '' THEN
        RAISE EXCEPTION 'invalid_completion_parameters';
    END IF;

    -- Lock the job to serialize completion and recovery.
    SELECT *
    INTO v_job
    FROM public.delivery_jobs
    WHERE id = p_job_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'result', 'not_found'
        );
    END IF;

    -- A stale or duplicate worker cannot complete this job.
    IF v_job.status <> 'processing'
       OR v_job.lease_token IS DISTINCT FROM p_lease_token THEN
        RETURN jsonb_build_object(
            'result', 'rejected',
            'reason', 'invalid_or_expired_lease',
            'job_id', p_job_id
        );
    END IF;

    -- Record the confirmed ERP reference.
    UPDATE public.orders
    SET order_status = 'delivered',
        odoo_order_id = v_odoo_order_id,
        updated_at = clock_timestamp()
    WHERE id = v_job.order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'order_not_found';
    END IF;

    -- Complete job and clear lease.
    UPDATE public.delivery_jobs
    SET status = 'succeeded',
        completed_at = clock_timestamp(),
        locked_at = NULL,
        lease_token = NULL,
        last_error = NULL,
        error_category = NULL,
        updated_at = clock_timestamp()
    WHERE id = p_job_id;

    -- Append completion audit.
    INSERT INTO public.audit_events (
        order_id,
        job_id,
        event_type,
        details
    )
    VALUES (
        v_job.order_id,
        p_job_id,
        'delivery_succeeded',
        jsonb_build_object(
            'odoo_order_id', v_odoo_order_id,
            'attempt', v_job.attempts
        )
    );

    RETURN jsonb_build_object(
        'result', 'succeeded',
        'job_id', p_job_id,
        'order_id', v_job.order_id,
        'odoo_order_id', v_odoo_order_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_delivery_job(
    uuid, uuid, text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.complete_delivery_job(
    uuid, uuid, text
) TO gateway_app;

COMMIT;
