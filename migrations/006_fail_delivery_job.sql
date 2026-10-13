
BEGIN;

CREATE OR REPLACE FUNCTION public.fail_delivery_job(
    p_job_id uuid,
    p_lease_token uuid,
    p_error_category text,
    p_error_message text,
    p_retryable boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_job public.delivery_jobs%ROWTYPE;
    v_category text;
    v_message text;
    v_new_status text;
    v_backoff_seconds integer;
    v_next_attempt_at timestamptz;
BEGIN
    v_category := btrim(p_error_category);
    v_message := btrim(p_error_message);

    IF p_job_id IS NULL
       OR p_lease_token IS NULL
       OR p_retryable IS NULL
       OR v_category IS NULL
       OR v_category = ''
       OR v_message IS NULL
       OR v_message = '' THEN
        RAISE EXCEPTION 'invalid_failure_parameters';
    END IF;

    -- Serialize failure handling with completion/recovery.
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

    -- Reject stale or duplicate workers.
    IF v_job.status <> 'processing'
       OR v_job.lease_token IS DISTINCT FROM p_lease_token THEN
        RETURN jsonb_build_object(
            'result', 'rejected',
            'reason', 'invalid_or_expired_lease',
            'job_id', p_job_id
        );
    END IF;

    IF p_retryable AND v_job.attempts < v_job.max_attempts THEN
        v_new_status := 'retry';

        -- Exponential backoff: 2, 4, 8, 16, 32 seconds.
        -- Cap at 60 seconds.
        v_backoff_seconds := LEAST(
            60,
            2 * power(
                2,
                LEAST(GREATEST(v_job.attempts - 1, 0), 5)
            )::integer
        );

        v_next_attempt_at :=
            clock_timestamp()
            + make_interval(secs => v_backoff_seconds);
    ELSE
        v_new_status := 'dead';
        v_backoff_seconds := NULL;
        v_next_attempt_at := NULL;
    END IF;

    UPDATE public.delivery_jobs
    SET status = v_new_status,
        next_attempt_at = COALESCE(
            v_next_attempt_at,
            next_attempt_at
        ),
        locked_at = NULL,
        lease_token = NULL,
        last_error = v_message,
        error_category = v_category,
        updated_at = clock_timestamp()
    WHERE id = p_job_id;

    -- Only permanently failed orders become failed.
    IF v_new_status = 'dead' THEN
        UPDATE public.orders
        SET order_status = 'failed',
            updated_at = clock_timestamp()
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
        p_job_id,
        CASE
            WHEN v_new_status = 'retry'
                THEN 'delivery_retry_scheduled'
            ELSE 'delivery_dead_lettered'
        END,
        jsonb_build_object(
            'attempt', v_job.attempts,
            'max_attempts', v_job.max_attempts,
            'error_category', v_category,
            'error_message', v_message,
            'retryable', p_retryable,
            'next_attempt_at', v_next_attempt_at,
            'backoff_seconds', v_backoff_seconds
        )
    );

    RETURN jsonb_build_object(
        'result', v_new_status,
        'job_id', p_job_id,
        'attempt', v_job.attempts,
        'error_category', v_category,
        'next_attempt_at', v_next_attempt_at,
        'backoff_seconds', v_backoff_seconds
    );
END;
$$;

REVOKE ALL ON FUNCTION public.fail_delivery_job(
    uuid, uuid, text, text, boolean
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.fail_delivery_job(
    uuid, uuid, text, text, boolean
) TO gateway_app;

COMMIT;
