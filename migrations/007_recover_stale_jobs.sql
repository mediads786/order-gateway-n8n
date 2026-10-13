
BEGIN;

CREATE OR REPLACE FUNCTION public.recover_stale_delivery_jobs(
    p_stale_seconds integer DEFAULT 120,
    p_limit integer DEFAULT 100
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_retried integer := 0;
    v_dead integer := 0;
    v_now timestamptz := clock_timestamp();
    v_job record;
    v_new_status text;
BEGIN
    IF p_stale_seconds IS NULL
       OR p_stale_seconds < 1
       OR p_limit IS NULL
       OR p_limit < 1
       OR p_limit > 100 THEN
        RAISE EXCEPTION 'invalid_recovery_parameters';
    END IF;

    FOR v_job IN
        SELECT j.id, j.order_id, j.attempts,
               j.max_attempts, j.lease_token,
               j.locked_at
        FROM public.delivery_jobs AS j
        WHERE j.status = 'processing'
          AND j.locked_at IS NOT NULL
          AND j.locked_at <=
              v_now - make_interval(secs => p_stale_seconds)
        ORDER BY j.locked_at, j.id
        LIMIT p_limit
        FOR UPDATE OF j SKIP LOCKED
    LOOP
        IF v_job.attempts < v_job.max_attempts THEN
            v_new_status := 'retry';
            v_retried := v_retried + 1;
        ELSE
            v_new_status := 'dead';
            v_dead := v_dead + 1;
        END IF;

        UPDATE public.delivery_jobs
        SET status = v_new_status,
            next_attempt_at = CASE
                WHEN v_new_status = 'retry'
                    THEN v_now
                ELSE next_attempt_at
            END,
            locked_at = NULL,
            lease_token = NULL,
            last_error = 'Worker lease expired',
            error_category = 'stale_worker',
            updated_at = v_now
        WHERE id = v_job.id;

        IF v_new_status = 'dead' THEN
            UPDATE public.orders
            SET order_status = 'failed',
                updated_at = v_now
            WHERE id = v_job.order_id;
        END IF;

        INSERT INTO public.audit_events (
            order_id,
            job_id,
            event_type,
            details
        )
        VALUES (
            v_job.order_id,
            v_job.id,
            CASE
                WHEN v_new_status = 'retry'
                    THEN 'delivery_stale_requeued'
                ELSE 'delivery_stale_dead_lettered'
            END,
            jsonb_build_object(
                'attempt', v_job.attempts,
                'max_attempts', v_job.max_attempts,
                'previous_lease_token', v_job.lease_token,
                'previous_locked_at', v_job.locked_at,
                'recovered_at', v_now
            )
        );
    END LOOP;

    RETURN jsonb_build_object(
        'result', 'completed',
        'requeued', v_retried,
        'dead', v_dead
    );
END;
$$;

REVOKE ALL ON FUNCTION public.recover_stale_delivery_jobs(
    integer, integer
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.recover_stale_delivery_jobs(
    integer, integer
) TO gateway_app;

COMMIT;
