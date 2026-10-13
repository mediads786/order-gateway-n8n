# Operations and recovery

This is a local demonstration runbook. [Setup](SETUP.md) covers initial provisioning; [Testing](TESTING.md) distinguishes safe synthetic checks from approved external writes.

## Read-only checks

```powershell
docker compose ps
docker compose logs --tail=100 n8n
docker compose exec -T postgres psql -U n8n_admin -d order_gateway -c "SELECT status,count(*) FROM delivery_jobs GROUP BY status ORDER BY status;"
docker compose exec -T postgres psql -U n8n_admin -d order_gateway -c "SELECT id,order_id,attempts,last_error,error_category FROM delivery_jobs WHERE status='dead';"
```

Keep logs private. Inspect order-specific audit and external references before deciding recovery. Pending retry due times are eligibility deadlines; the minute worker schedule can add delay. Stale jobs are recovered by Module 02 after 120 seconds, with ownership protection and attempt-budget enforcement.

## Manual dead-letter recovery

Identify the cause and check whether the ERP already created the stable external reference. Correct operational conditions only under authorization. Do not delete the external order or generate a different reference to bypass an uncertain result. Use the existing privileged function in an administrator client, replacing the UUID and reason:

```sql
SELECT public.requeue_dead_delivery_job(
    '<reviewed-job-uuid>'::uuid,
    'Operator verified failure cause removed; approved retry'
);
```

Expected queued job, attempts 0, accepted local order and `delivery_manually_requeued` audit. The next claim receives a new lease; verify actual ERP readback, `succeeded`/`delivered` and completion audit. The worker identity cannot execute recovery. Old failed audit events remain and existing alert rows are not erased.

## Notification isolation

In a fresh synthetic environment leave Modules 04/06/07 inactive and unbind error handlers. On a shared demo instance, preserve published versions/activation, approve temporary isolation, stop test submissions and reconcile in-flight jobs before restoring. Outbox rows committed during faults may be sent when claimers resume; suppression must be restricted to approved QA-created rows with an explicit reason. Never falsely mark them sent or modify unrelated existing alerts. Gmail and WhatsApp `sent` refer to provider acceptance; inspect actual provider evidence when available. The custom `order_gateway_failure_alert` test passed direct API acceptance on 2026-10-13 (HTTP 200 — accepted, approved test number ending2077); phone delivery is **PASS — user confirmed receipt** on 2026-10-13. Modules 05/06 stayed unpublished and no queue/code/configuration changes were made by that test. Do not publish Module 06 merely to repeat a one-off test: publication enables scheduled processing of eligible queue entries. See [Verified testing summary](QA-TEST-REPORT.md) for the acceptance evidence and its limits.

## Persistence and backup

`docker compose stop` retains volumes. Never use volume deletion/reset as troubleshooting. The existing restart test verified persistence, not backup restore. Back up both PostgreSQL databases, n8n workflows, encrypted credential state and the encryption key through a private secure procedure. Dumps and credentials must stay outside public Git. A restore drill has not been performed; no recovery-time guarantee is claimed.

## Deployment limitations

Loopback binding is local-only. A tunnel used for a webhook is not production ingress, editor access control or a managed deployment. The n8n image is pinned to the tested 2.42.6 version; compatibility and security of later versions are not established by this milestone. Shared Odoo cron can affect unrelated persistent records even when a test creates only a draft. Do not operate the original Order-Gateway API/worker or recreate its Odoo container as part of this runbook without approval.

Before a public release, retain full QA history privately and publish only reviewed outcome summaries. Current Module 04 parameter conversion was verified without database writes or notification sends; no prefix-related functional correction is required in the installed node version. See [Release review](RELEASE-REVIEW.md) for the current verification boundary.
