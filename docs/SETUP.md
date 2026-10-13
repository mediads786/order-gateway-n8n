# Setup

Use a new, isolated local installation. Never run initialization against a populated shared database. Docker Desktop with Compose, PowerShell and access to the images are required. PostgreSQL client commands below run inside the container. The verified n8n version was 2.42.6; Compose pins that version; check compatibility before upgrading. PostgreSQL 16 worked in QA but the installed CLI emitted a support-compatibility warning.

## Start the stack

```powershell
if (Test-Path .env) { throw 'Existing .env: review it; do not overwrite credentials.' }
Copy-Item .env.example .env
# Edit .env privately: replace both placeholders with independently generated values.
docker compose config --quiet
docker compose up -d
docker compose ps
```

Open `http://localhost:5678` and complete n8n owner setup. Save the encryption key securely: changing it can prevent reading stored credentials. Do not publish `.env`. Compose initializes only the n8n database; it does not mount/run the business migrations. Named volumes persist data. Do not remove volumes to retry setup.

## Provision the business database — fresh installation only

First check for existing state:

```powershell
docker compose exec -T postgres psql -U n8n_admin -d n8n -c "SELECT datname FROM pg_database WHERE datname='order_gateway';"
docker compose exec -T postgres psql -U n8n_admin -d n8n -c "SELECT rolname FROM pg_roles WHERE rolname='gateway_app';"
```

If either exists, stop initialization and review the existing schema/migration state. Otherwise open an interactive client:

```powershell
docker compose exec postgres psql -U n8n_admin -d n8n
```

```sql
CREATE ROLE gateway_app LOGIN;
\password gateway_app
CREATE DATABASE order_gateway OWNER n8n_admin;
\connect order_gateway
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT CONNECT ON DATABASE order_gateway TO gateway_app;
GRANT USAGE ON SCHEMA public TO gateway_app;
\quit
```

The password prompt avoids putting the application password in SQL files. `gen_random_uuid()` is available in PostgreSQL 16; migration 009 uses built-in MD5, not an extension. Apply actual migrations in lexical order (001–013), only once on the new business database:

```powershell
Get-ChildItem migrations/*.sql | Sort-Object Name | ForEach-Object {
    Get-Content -Raw $_.FullName |
        docker compose exec -T postgres psql -U n8n_admin -d order_gateway -v ON_ERROR_STOP=1
    if ($LASTEXITCODE -ne 0) { throw "Migration failed: $($_.Name)" }
}
```

There is no migration ledger or automatic upgrader. Initial migrations create tables/functions; do not treat all scripts as safe repeated bootstrap operations. Manual recovery runs as the administrator, not the worker credential.

## Credentials and import order

Use **Import from file** in n8n for the JSON objects in `workflows/`. All public exports are inactive and contain no credential bindings, pinned payloads or local instance workflow IDs. Import is preparation only; credentials and node parameters must be configured before publication.

| Order | File/module | Configure before use |
|---|---|---|
| 1 | 00 optional diagnostic | PostgreSQL credential; manual read-only query |
| 2 | 07 Workflow Error Alert | Gmail OAuth2 and approved recipient; leave inactive for local tests |
| 3 | 03 Mock ERP | PostgreSQL credential, POST path `mock-erp-orders` |
| 4 | 02 ERP Delivery Worker | PostgreSQL; internal mock URL `http://n8n:5678/webhook/mock-erp-orders` |
| 5 | 01 Shopify Order Intake | PostgreSQL and Crypto HMAC secret; POST path `shopify-orders` |
| 6 | 04 Delivery Failure Notifications | PostgreSQL, Gmail OAuth2, approved recipient; do not enable during fault tests |
| 7 | 05 WhatsApp API Test | Meta custom authentication, phone-number ID and approved test recipient; manual only |
| 8 | 06 WhatsApp Failure Notifications | PostgreSQL and Meta authentication, phone-number ID/recipient, approved template; keep inactive for one-off tests; publish only when scheduled notifications are intended |

PostgreSQL credential: host `postgres`, port `5432`, database `order_gateway`, user `gateway_app`, the private password set above; this is distinct from n8n's internal database. Bind it to every Postgres node. Crypto credential: populate the HMAC secret associated with the development store's webhook subscription, or a separate synthetic secret for local-only testing. Gmail uses OAuth2. Meta nodes use `httpTemplatedCustomAuth`; configure the Authorization bearer header securely using your own token. Never paste tokens into node JSON.

After importing 07, select it in the **Error workflow** settings of 01, 02 and 03 if you intend to send alerts. Old instance-specific error-workflow IDs were removed from exports. For notification-free local testing leave the error handler unset and 04/06/07 inactive. Module 05 uses `hello_world`/`en_US`; 06 uses `order_gateway_failure_alert`/`en` with three body parameters. The configured `order_gateway_failure_alert` / `en` template passed a direct Meta API test on 2026-10-13 (HTTP 200 — accepted, approved test number ending2077), with both Modules 05/06 unpublished and no queue/code/configuration changes. Phone delivery is **PASS — user confirmed receipt** on 2026-10-13. One-off testing does not require publication; publishing 06 enables scheduled queue processing. In a new environment verify that environment's provider approval/availability before any authorized send. Placeholder recipients intentionally cannot serve as live destinations.

Module 04 retains a noncanonical leading-equals prefix in its query parameters. Installed PostgreSQL node2.7 explicitly normalizes it; safe parameter-conversion tests passed. No workflow edit is required for this setting. A different n8n/node version should be checked before claiming identical compatibility. See [Release review](RELEASE-REVIEW.md).

Publish 03 first, then 01, then 02 for a mock demo. 02 runs every minute and claims available jobs, so use an isolated database. A webhook-test path works only while listening; active production paths are `/webhook/shopify-orders` and `/webhook/mock-erp-orders`. Importing does not publish a workflow automatically.

## Optional real Shopify and Odoo

A real Shopify store requires HTTPS forwarding to local n8n and a separate `orders/create` JSON subscription at `https://<your-host>/webhook/shopify-orders`. Associate the actual signing secret with the Crypto credential; verify raw-body HMAC. A quick Cloudflare hostname can change/expire; the old test hostname is evidence, not a reusable configuration. Do not alter any unrelated subscription or expose the n8n editor publicly without deployment controls.

The Odoo QA JSON in `workflows/optional/` is an alternative worker, not an additional scheduled worker. Review its guarded store/note, `ODOO_TEST_HOST`, `X-Odoo-Database`, partner/product/company/tax IDs, USD assumption and existing tax rules. Bind a secure Header Auth credential (Authorization bearer API key); allow network access to an isolated Odoo 19 instance. The exact tested fixture and draft-only steps are in [Testing](TESTING.md) and the [verified testing summary](QA-TEST-REPORT.md). The Compose file does not provide Odoo or a tunnel. Preparation does not create external records. Credentials are configured locally by the operator; any live test order requires explicit authorization.

## Verification and stopping

Run [Testing](TESTING.md) using synthetic records and check database state. Inspect `docker compose logs --tail=100 n8n` privately because execution errors can include request data. To stop without removing persistent data use `docker compose stop`. A clean-volume bootstrap (Compose, provisioning, migrations 001-013) was verified on 2026-10-13; importing the sanitized workflows into a fresh n8n instance and backup restore were not re-run; report any environment/version mismatch before a live integration.
