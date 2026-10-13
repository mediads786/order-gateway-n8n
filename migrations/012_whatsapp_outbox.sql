
BEGIN;

CREATE TABLE public.whatsapp_notification_outbox (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    audit_event_id bigint NOT NULL UNIQUE
        REFERENCES public.audit_events(id),

    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN (
            'pending', 'sending', 'sent', 'retry', 'dead'
        )),

    attempts integer NOT NULL DEFAULT 0
        CHECK (attempts >= 0),

    max_attempts integer NOT NULL DEFAULT 5
        CHECK (max_attempts > 0),

    next_attempt_at timestamptz NOT NULL DEFAULT now(),

    locked_at timestamptz,
    lease_token uuid,
    last_error text,

    whatsapp_message_id text,
    sent_at timestamptz,

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_whatsapp_notifications_ready
ON public.whatsapp_notification_outbox (
    next_attempt_at, created_at
)
WHERE status IN ('pending', 'retry');

CREATE INDEX idx_whatsapp_notifications_stale
ON public.whatsapp_notification_outbox (locked_at)
WHERE status = 'sending';


-- Create an independent WhatsApp notification
-- for each NEW dead-letter audit event.

CREATE OR REPLACE FUNCTION
public.enqueue_whatsapp_failure_notification()
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
        INSERT INTO public.whatsapp_notification_outbox (
            audit_event_id
        )
        VALUES (NEW.id)
        ON CONFLICT (audit_event_id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enqueue_whatsapp_failure
AFTER INSERT ON public.audit_events
FOR EACH ROW
EXECUTE FUNCTION
    public.enqueue_whatsapp_failure_notification();


-- Prevent direct writes by the automated worker.
-- Controlled functions will receive EXECUTE permissions
-- in the next migration.

REVOKE ALL ON TABLE
    public.whatsapp_notification_outbox
FROM PUBLIC;

REVOKE ALL ON FUNCTION
    public.enqueue_whatsapp_failure_notification()
FROM PUBLIC;

COMMIT;
