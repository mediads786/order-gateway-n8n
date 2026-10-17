# Testing and evidence

[QA-TEST-REPORT.md](QA-TEST-REPORT.md) is the concise public verified-results summary; the full internal execution history is preserved privately. SQL function tests, isolated Code assertions, actual n8n executions, mock ERP integration and real external tests are separate evidence layers. A green execution alone is insufficient: verify business records, amounts, external references and audits.

## Safe local reproduction

Complete [Setup](SETUP.md) in an isolated database with 01/02/03 enabled. Keep 04/06/07 inactive and 01–03 error handlers unset while testing, and do not run manual Module 05. Record unique order/webhook IDs for every run; retain records rather than resetting the database. Use synthetic customer details only.

`test-order.json` is the existing synthetic fixture. Change its order and line IDs for a new run. The existing `concurrent-test.sql` is a direct SQL fixture with fixed IDs, not an authenticated webhook or automated test suite. Run it in two independent clients only in your isolated database; expect one acceptance and one duplicate on its first concurrent use. Reusing it later yields duplicates, not a new acceptance test.

### Signed intake and replay (PowerShell)

Use a synthetic secret matching your n8n Crypto credential. This example sends the file's exact UTF-8 bytes, not reserialized JSON. It does not print the secret or signature.

```powershell
$secret = Read-Host 'Synthetic HMAC secret' -AsSecureString
$plain = [System.Net.NetworkCredential]::new('', $secret).Password
$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path test-order.json))
$hmac = [System.Security.Cryptography.HMACSHA256]::new([Text.Encoding]::UTF8.GetBytes($plain))
$signature = [Convert]::ToBase64String($hmac.ComputeHash($bytes))
$headers = @{
    'X-Shopify-Hmac-Sha256' = $signature
    'X-Shopify-Shop-Domain' = 'test-store.myshopify.com'
    'X-Shopify-Webhook-Id' = [guid]::NewGuid().ToString()
    'X-Shopify-Topic' = 'orders/create'
}
$uri = 'http://localhost:5678/webhook/shopify-orders'
Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $bytes
# Exact replay uses the same bytes and headers:
Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $bytes
$hmac.Dispose()
Remove-Variable plain,signature,secret
```

Expect accepted then duplicate/webhook_replay, both HTTP 200. After the next worker cycle, expect one local order/job/mock reference, delivered/succeeded and acceptance/claim/success audits. Source fixture email is synthetic. Invalid signature should return 401 with no business write. A signed empty SKU should return 400 and a rejection receipt/audit. A new webhook ID with changed existing order data returns an authenticated conflict at HTTP 200; do not mislabel that as acceptance.

### Read-only business verification

```powershell
docker compose exec -T postgres psql -U n8n_admin -d order_gateway -c "SELECT shopify_order_id,order_status,odoo_order_id FROM orders WHERE shop_domain='test-store.myshopify.com';"
docker compose exec -T postgres psql -U n8n_admin -d order_gateway -c "SELECT o.shopify_order_id,j.status,j.attempts,j.lease_token FROM delivery_jobs j JOIN orders o ON o.id=j.order_id WHERE o.shop_domain='test-store.myshopify.com';"
docker compose exec -T postgres psql -U n8n_admin -d order_gateway -c "SELECT event_type,count(*) FROM audit_events GROUP BY event_type ORDER BY event_type;"
```

In n8n record intake, worker and mock execution IDs and inspect node outputs without publishing raw customer data. Join a specific order's lines, receipt, job, mock reference and audit events for precise evidence; global counts alone cannot prove that fixture's correctness.

## Reliability regression scenarios

| Scenario | Procedure and required outcome | Existing evidence |
|---|---|---|
| Concurrent signed intake | Eight overlapping identical raw requests; one acceptance/job/mock outcome | Verified mock QA, 572–579, 581/582 |
| Atomic rollback | Direct function call with valid first/invalid second line; compare all five intake table counts in isolated transaction | Verified mock QA, SQL only |
| Transient retry/exhaustion | Isolated fault proxy returns 503 only for QA references; observe real due times and scheduled worker transitions, then fifth-attempt DLQ | Verified reliability QA, 684–689; temporary proxy not shipped |
| Manual recovery | Remove fixture fault, privileged audited requeue; next actual worker succeeds | Verified reliability QA, 692/693; recovery itself is SQL |
| Concurrent workers | Delayed QA mock responses overlap schedules; each job has one current lease/claim and one external reference | Verified reliability QA, 692/694/699 |
| Post-create interruption | Hold response after mock commit, interrupt worker under explicit operator approval; stale recovery reconciles same mock ID | Verified reliability QA, 713/714 then 716/717 |
| Restart persistence | Compare table fingerprints while worker stopped; restart PostgreSQL/n8n, resume isolated queued job and replay | Verified mock QA, 586/587/590 |

Fault proxy and one-off audit harnesses are not present in this repository. These rows describe historical procedures, not runnable automation supplied here. Reconstruct them only in an isolated environment after reviewing notification suppression and shutdown safety. Do not kill shared services or advance live due times. Every new run must record timestamps, expected/actual, PASS/FAIL/NOT TESTED, execution IDs and database evidence in a private run log. Update the public summary only with reviewed final outcomes and any unresolved material findings.

## Real Shopify → Odoo: verified fixture, not default setup

The controlled live test created Shopify #1018 (paid, unfulfilled), `ABC`, 2 × USD 111, and delivered through executions 1131/1132 to draft S00048. The QA branch mapped ABC to Odoo product 42/GWDEMO1 and partner 15; local source SKU remained ABC. Odoo subtotal222/tax33.30/total255.30 intentionally differs from Shopify222/tax0. Execution 1135 replayed the exact signed bytes/delivery ID: HTTP200 duplicate, one order/job/line/receipt and one quotation remained. Local audit193/194/195 matches delivered/succeeded attempt1. No Odoo picking/invoice links were created.

To repeat, independently verify a development store, signing-secret association, test customer/product/tax fixtures, Odoo JSON-2 permission and guarded optional worker configuration. Obtain approval before creating external records. Isolate notifications; create one approved test order, verify HMAC/persistence/draft readback, then replay securely preserved exact bytes. Never use public report IDs as fresh fixtures or assume the old tunnel is active. Restore the mock worker and retain records afterward. Real Odoo timeout/concurrent-create faults remain unverified.

## Notification evidence and limits

Module 04 success190/191 and failure197, Module 07 actual error535, WhatsApp standalone252 and outbox272/277 prove previously exercised send/completion/retry branches. Those successful WhatsApp sends and user confirmations remain verified; they are separate from the latest custom-template test.

On **2026-10-13 at 10:17:16 Asia/Karachi**, Codex verified `order_gateway_failure_alert` / `en` with three synthetic body parameters and approved test recipient. Meta returned **HTTP 200 — accepted**, a message ID and `message_status: accepted`: **PASS for custom-template API acceptance**. The test used the saved Module 06 request configuration directly; it did not execute Module 05's `hello_world` test or the Module 06 scheduled outbox workflow. At that direct-API checkpoint, both Modules 05/06 remained unpublished/inactive, and no queue, code or configuration changes were made by that test. The owner subsequently confirms activating and testing the failure-notification workflow after template approval; see [notification verification follow-up](NOTIFICATION-VERIFICATION.md).

Actual phone delivery of this custom-template test is **PASS — user confirmed receipt**. On 2026-10-13 the user explicitly confirmed receiving the message at the approved test recipient. The user's handset receipt confirmation is the delivery evidence; no independent Meta delivery-status webhook receipt was captured. Provider acceptance alone does not establish phone delivery, but this subsequent receipt confirmation does. Custom-template API acceptance and phone delivery are no longer pending at this checkpoint. See [Verified testing summary](QA-TEST-REPORT.md) for the retained reference and evidence boundary. This documentation update ran no new tests. Obtain explicit recipient/send authorization before repeating any external notification test.

Clean-install bootstrap and actual backup restore remain NOT TESTED. Local Markdown/export verification performed for release does not replace them.

## Static repository verification

With Node.js installed, run `node scripts/verify-release.js` from the project root. It reads JSON/Markdown locally, compiles Code/expression syntax without executing workflow code, checks connection targets and manifest hashes, and reports broken local links/private bindings. It does not contact any services, import workflows, send messages or validate n8n version compatibility. The checker recognizes the installed PostgreSQL node query-parameter normalization; it does not mistake Module 04’s retained leading-equals prefix for a generic syntax defect. A fresh n8n import/runtime regression remains distinct from these static checks.
