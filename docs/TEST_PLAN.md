# Regression test plan

This plan reflects the completed implementation. [Verified testing summary](QA-TEST-REPORT.md) records results; [Testing](TESTING.md) provides reproduction instructions. Earlier intake-only checkpoint material is retained privately. A PASS applies to the exercised layer, not to untested external scenarios.

| Area | Regression objective | Verified coverage / remaining boundary |
|---|---|---|
| Intake authentication | Verify exact raw-byte HMAC; reject absent/invalid signatures before business writes | Synthetic HMAC checks and actual signed intake verified; malformed infrastructure-error edges not comprehensively covered |
| Mapping/validation | Preserve source identifiers/SKU, reject invalid required fields | Current isolated validation checks pass; n8n acceptance/rejection and mock mapping verified |
| Atomicity | Invalid second line rolls back order/lines/job/receipt/audit | Verified SQL-only test |
| Webhook idempotency | Same delivery replay and same-order concurrent delivery produce one job | Actual overlapping webhook requests and real Shopify exact replay verified |
| Conflicting data | Changed orders/create payload creates no replacement order/job | SQL and synthetic intake coverage; not general order-update support |
| Durable worker | Persist due state; claim without competing ownership; validate ERP ID before completion | Actual scheduled mock worker verified |
| Transient/exhausted failures | Respect due times/backoff; exhausted/permanent outcomes reach DLQ | Controlled mock faults and SQL classification verified; real Odoo faults not verified |
| Ownership and stale recovery | Reject stale lease; reconcile interrupted external creation | SQL lease protection and actual mock crash recovery verified |
| Manual recovery | Privileged audited reset, then one actual delivery | SQL operator action plus actual mock worker verified |
| Restart | Preserve data/credentials/queue and resume | Graceful PostgreSQL/n8n restart verified; backup restore untested |
| Notifications | Send/complete/fail branches; do not notify customers during other QA | Prior Gmail and WhatsApp sending/outbox evidence retained; custom `order_gateway_failure_alert` API acceptance **PASS**, HTTP200/accepted on 2026-10-13, approved test number ending2077; actual phone delivery **PASS — user confirmed receipt** on 2026-10-13. Modules05/06 remained unpublished, with no queue/code/configuration changes; no new scheduled/outbox regression |
| Odoo fixture | One approved Shopify order becomes matching draft quotation; replay does not duplicate | Real #1018 → S00048 verified; no confirmation/invoice/stock behavior included |
| Release artifacts | Credentials/pinned data absent, links valid, sources included | Read-only static checks; fresh-instance import/install remains untested |

For new tests use isolated synthetic records, keep notification senders/error handlers disabled, and obtain authorization before external writes or shared-service interruption. Record expected/actual results, timestamps, layer, execution IDs and database/external evidence in a private run log; publish only a reviewed current summary. Do not reset existing databases or discard failed evidence.
