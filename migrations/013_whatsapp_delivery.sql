
BEGIN;

-- 1. Claim ready WhatsApp notifications

CREATE OR REPLACE FUNCTION public.claim_whatsapp_notifications(
    p_limit integer DEFAULT 1
)
RETURNS TABLE (
    notification_id uuid,
    claim_lease_token uuid,
    audit_event_id bigint,
    event_type text,
    job_id uuid,
    order_id uuid,
    event_details jsonb,
    claim_attempt integer
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
        SELECT n.id
        FROM public.whatsapp_notification_outbox AS n
        WHERE n.status IN ('pending', 'retry')
          AND n.next_attempt_at <= now()
          AND n.attempts < n.max_attempts
        ORDER BY n.next_attempt_at, n.created_at, n.id
        LIMIT p_limit
        FOR UPDATE OF n SKIP LOCKED
    ),
    claimed AS (
        UPDATE public.whatsapp_notification_outbox AS n
        SET status = 'sending',
            attempts = n.attempts + 1,
            locked_at = clock_timestamp(),
            lease_token = gen_random_uuid(),
            updated_at = clock_timestamp(),
            last_error = NULL
        FROM eligible AS e
        WHERE n.id = e.id
        RETURNING
            n.id,
            n.audit_event_id,
            n.lease_token,
            n.attempts
    )
    SELECT
        c.id,
        c.lease_token,
        c.audit_event_id,
        a.event_type,
        a.job_id,
        a.order_id,
        a.details,
        c.attempts
    FROM claimed AS c
    JOIN public.audit_events AS a
        ON a.id = c.audit_event_id;
END;
$$;


-- 2. Record successful Meta API acceptance

CREATE OR REPLACE FUNCTION public.complete_whatsapp_notification(
    p_notification_id uuid,
    p_lease_token uuid,
    p_message_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_notification public.whatsapp_notification_outbox%ROWTYPE;
    v_message_id text := btrim(p_message_id);
BEGIN
    IF p_notification_id IS NULL
       OR p_lease_token IS NULL
       OR NULLIF(v_message_id, '') IS NULL THEN
        RAISE EXCEPTION 'invalid_completion_parameters';
    END IF;

    SELECT *
    INTO v_notification
    FROM public.whatsapp_notification_outbox
    WHERE id = p_notification_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('result', 'not_found');
    END IF;

    IF v_notification.status <> 'sending'
       OR v_notification.lease_token IS DISTINCT FROM p_lease_token THEN
        RETURN jsonb_build_object(
            'result', 'rejected',
            'reason', 'invalid_or_expired_lease'
        );
    END IF;

    UPDATE public.whatsapp_notification_outbox
    SET status = 'sent',
        whatsapp_message_id = v_message_id,
        sent_at = clock_timestamp(),
        locked_at = NULL,
        lease_token = NULL,
        last_error = NULL,
        updated_at = clock_timestamp()
    WHERE id = p_notification_id;

    RETURN jsonb_build_object(
        'result', 'sent',
        'notification_id', p_notification_id,
        'whatsapp_message_id', v_message_id
    );
END;
$$;


-- 3. Record failure and schedule retry

CREATE OR REPLACE FUNCTION public.fail_whatsapp_notification(
    p_notification_id uuid,
    p_lease_token uuid,
    p_error_message text,
    p_retryable boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_notification public.whatsapp_notification_outbox%ROWTYPE;
    v_status text;
    v_delay integer;
    v_next_attempt timestamptz;
BEGIN
    IF p_notification_id IS NULL
       OR p_lease_token IS NULL
       OR p_retryable IS NULL
       OR NULLIF(btrim(p_error_message), '') IS NULL THEN
        RAISE EXCEPTION 'invalid_failure_parameters';
    END IF;

    SELECT *
    INTO v_notification
    FROM public.whatsapp_notification_outbox
    WHERE id = p_notification_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('result', 'not_found');
    END IF;

    IF v_notification.status <> 'sending'
       OR v_notification.lease_token IS DISTINCT FROM p_lease_token THEN
        RETURN jsonb_build_object(
            'result', 'rejected',
            'reason', 'invalid_or_expired_lease'
        );
    END IF;

    IF p_retryable
       AND v_notification.attempts < v_notification.max_attempts THEN

        v_status := 'retry';

        v_delay := LEAST(
            60,
            2 * power(
                2,
                LEAST(GREATEST(v_notification.attempts - 1, 0), 5)
            )::integer
        );

        v_next_attempt :=
            clock_timestamp() + make_interval(secs => v_delay);
    ELSE
        v_status := 'dead';
        v_delay := NULL;
        v_next_attempt := NULL;
    END IF;

    UPDATE public.whatsapp_notification_outbox
    SET status = v_status,
        next_attempt_at = COALESCE(v_next_attempt, next_attempt_at),
        locked_at = NULL,
        lease_token = NULL,
        last_error = btrim(p_error_message),
        updated_at = clock_timestamp()
    WHERE id = p_notification_id;

    RETURN jsonb_build_object(
        'result', v_status,
        'notification_id', p_notification_id,
        'attempt', v_notification.attempts,
        'backoff_seconds', v_delay,
        'next_attempt_at', v_next_attempt
    );
END;
$$;


-- 4. Recover abandoned WhatsApp notifications

CREATE OR REPLACE FUNCTION public.recover_stale_whatsapp_notifications(
    p_stale_seconds integer DEFAULT 120,
    p_limit integer DEFAULT 100
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_now timestamptz := clock_timestamp();
    v_notification record;
    v_status text;
    v_requeued integer := 0;
    v_dead integer := 0;
BEGIN
    IF p_stale_seconds IS NULL
       OR p_stale_seconds < 1
       OR p_limit IS NULL
       OR p_limit < 1
       OR p_limit > 100 THEN
        RAISE EXCEPTION 'invalid_recovery_parameters';
    END IF;

    FOR v_notification IN
        SELECT n.id, n.attempts, n.max_attempts
        FROM public.whatsapp_notification_outbox AS n
        WHERE n.status = 'sending'
          AND n.locked_at IS NOT NULL
          AND n.locked_at <=
              v_now - make_interval(secs => p_stale_seconds)
        ORDER BY n.locked_at, n.id
        LIMIT p_limit
        FOR UPDATE OF n SKIP LOCKED
    LOOP
        IF v_notification.attempts < v_notification.max_attempts THEN
            v_status := 'retry';
            v_requeued := v_requeued + 1;
        ELSE
            v_status := 'dead';
            v_dead := v_dead + 1;
        END IF;

        UPDATE public.whatsapp_notification_outbox
        SET status = v_status,
            next_attempt_at = CASE
                WHEN v_status = 'retry' THEN v_now
                ELSE next_attempt_at
            END,
            locked_at = NULL,
            lease_token = NULL,
            last_error = 'WhatsApp worker lease expired',
            updated_at = v_now
        WHERE id = v_notification.id;
    END LOOP;

    RETURN jsonb_build_object(
        'result', 'completed',
        'requeued', v_requeued,
        'dead', v_dead
    );
END;
$$;


-- 5. Restricted permissions

REVOKE ALL ON FUNCTION public.claim_whatsapp_notifications(integer)
FROM PUBLIC;

REVOKE ALL ON FUNCTION public.complete_whatsapp_notification(
    uuid,uuid,text
) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.fail_whatsapp_notification(
    uuid,uuid,text,boolean
) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.recover_stale_whatsapp_notifications(
    integer,integer
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.claim_whatsapp_notifications(integer)
TO gateway_app;

GRANT EXECUTE ON FUNCTION public.complete_whatsapp_notification(
    uuid,uuid,text
) TO gateway_app;

GRANT EXECUTE ON FUNCTION public.fail_whatsapp_notification(
    uuid,uuid,text,boolean
) TO gateway_app;

GRANT EXECUTE ON FUNCTION public.recover_stale_whatsapp_notifications(
    integer,integer
) TO gateway_app;

COMMIT;
