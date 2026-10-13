
BEGIN;

CREATE OR REPLACE FUNCTION public.claim_delivery_jobs(
    p_limit integer DEFAULT 5
)
RETURNS TABLE (
    job_id uuid,
    claimed_order_id uuid,
    claim_lease_token uuid,
    claim_attempt integer,
    claim_max_attempts integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
    IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
        RAISE EXCEPTION 'invalid_claim_limit';
    END IF;

    RETURN QUERY
    WITH eligible AS MATERIALIZED (
        SELECT j.id
        FROM public.delivery_jobs AS j
        WHERE j.status IN ('queued', 'retry')
          AND j.next_attempt_at <= now()
          AND j.attempts < j.max_attempts
        ORDER BY j.next_attempt_at, j.created_at, j.id
        LIMIT p_limit
        FOR UPDATE OF j SKIP LOCKED
    ),
    claimed AS (
        UPDATE public.delivery_jobs AS j
        SET status = 'processing',
            attempts = j.attempts + 1,
            locked_at = clock_timestamp(),
            lease_token = gen_random_uuid(),
            updated_at = clock_timestamp(),
            last_error = NULL,
            error_category = NULL
        FROM eligible AS e
        WHERE j.id = e.id
        RETURNING
            j.id,
            j.order_id,
            j.lease_token,
            j.attempts,
            j.max_attempts
    ),
    audited AS (
        INSERT INTO public.audit_events AS ae (
            order_id,
            job_id,
            event_type,
            details
        )
        SELECT
            c.order_id,
            c.id,
            'delivery_claimed',
            jsonb_build_object(
                'attempt', c.attempts,
                'max_attempts', c.max_attempts,
                'lease_token', c.lease_token
            )
        FROM claimed AS c
        RETURNING ae.job_id
    )
    SELECT
        c.id,
        c.order_id,
        c.lease_token,
        c.attempts,
        c.max_attempts
    FROM claimed AS c
    JOIN audited AS a ON a.job_id = c.id;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_delivery_jobs(integer)
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.claim_delivery_jobs(integer)
TO gateway_app;

COMMIT;
