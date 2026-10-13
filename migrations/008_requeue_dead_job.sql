
BEGIN;

CREATE OR REPLACE FUNCTION public.requeue_dead_delivery_job(
    p_job_id uuid,
    p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_job public.delivery_jobs%ROWTYPE;
    v_reason text;
    v_now timestamptz := clock_timestamp();
BEGIN
    v_reason := btrim(p_reason);

    IF p_job_id IS NULL
       OR v_reason IS NULL
       OR length(v_reason) < 5 THEN
        RAISE EXCEPTION 'invalid_recovery_parameters';
    END IF;

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

    IF v_job.status <> 'dead' THEN
        RETURN jsonb_build_object(
            'result', 'rejected',
            'reason', 'job_not_dead',
            'job_id', p_job_id
        );
    END IF;

    -- Reset the job for a new delivery cycle.
    UPDATE public.delivery_jobs
    SET status = 'queued',
        attempts = 0,
        next_attempt_at = v_now,
        locked_at = NULL,
        lease_token = NULL,
        last_error = NULL,
        error_category = NULL,
        completed_at = NULL,
        updated_at = v_now
    WHERE id = p_job_id;

    UPDATE public.orders
    SET order_status = 'accepted',
        updated_at = v_now
    WHERE id = v_job.order_id;

    INSERT INTO public.audit_events (
        order_id,
        job_id,
        event_type,
        details
    )
    VALUES (
        v_job.order_id,
        p_job_id,
        'delivery_manually_requeued',
        jsonb_build_object(
            'reason', v_reason,
            'previous_attempts', v_job.attempts,
            'previous_error', v_job.last_error,
            'previous_error_category', v_job.error_category
        )
    );

    RETURN jsonb_build_object(
        'result', 'queued',
        'job_id', p_job_id,
        'attempts', 0,
        'reason', v_reason
    );
END;
$$;

REVOKE ALL ON FUNCTION public.requeue_dead_delivery_job(
    uuid, text
) FROM PUBLIC;

-- Intentionally no gateway_app grant.
-- Manual recovery must not be callable by the
-- automated delivery worker's database identity.

COMMIT;
