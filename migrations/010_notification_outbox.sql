
BEGIN;

CREATE TABLE public.notification_outbox (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    audit_event_id bigint NOT NULL UNIQUE
        REFERENCES public.audit_events(id),
    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'sending', 'sent', 'retry', 'dead')),
    attempts integer NOT NULL DEFAULT 0
        CHECK (attempts >= 0),
    max_attempts integer NOT NULL DEFAULT 5
        CHECK (max_attempts > 0),
    next_attempt_at timestamptz NOT NULL DEFAULT now(),
    locked_at timestamptz,
    lease_token uuid,
    last_error text,
    sent_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_notification_outbox_ready
ON public.notification_outbox(next_attempt_at, created_at)
WHERE status IN ('pending', 'retry');

CREATE INDEX idx_notification_outbox_stale
ON public.notification_outbox(locked_at)
WHERE status = 'sending';

-- Automatically create a notification whenever
-- a delivery enters the dead-letter state.

CREATE OR REPLACE FUNCTION public.enqueue_dead_letter_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
    IF NEW.event_type IN (
        'delivery_dead_lettered',
        'delivery_stale_dead_lettered'
    ) THEN
        INSERT INTO public.notification_outbox (
            audit_event_id
        )
        VALUES (NEW.id)
        ON CONFLICT (audit_event_id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enqueue_dead_letter_notification
AFTER INSERT ON public.audit_events
FOR EACH ROW
EXECUTE FUNCTION public.enqueue_dead_letter_notification();

REVOKE ALL ON public.notification_outbox FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enqueue_dead_letter_notification()
FROM PUBLIC;

COMMIT;
