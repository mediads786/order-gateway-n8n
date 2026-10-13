# Workflow inventory and import contract

Current sanitized exports are in `../workflows/`; [manifest](../workflows/manifest.json) records source activation, node counts and SHA-256 fingerprints. All exports are intentionally inactive, credential-free and contain empty pinData. Active workflows were read from their published history versions; inactive workflows use saved definitions. No running workflow was changed by repository preparation.

| Module | Export | Nodes | Verified runtime baseline |
|---|---|---:|---|
| 00 | [Connection diagnostic](../workflows/00-postgresql-connection-test.json) | 2 | Manual, inactive |
| 01 | [Shopify intake](../workflows/01-shopify-order-intake.json) | 12 | Published; raw-body hash/HMAC → field validation → SQL accept/reject → HTTP response |
| 02 | [Delivery worker](../workflows/02-erp-delivery-worker.json) | 10 | Published; minute schedule → stale recovery → claim/load/map → mock HTTP → classify → complete/fail |
| 03 | [Mock ERP](../workflows/03-mock-erp.json) | 6 | Published corrected validator → SQL reference persistence → response |
| 04 | [Gmail outbox](../workflows/04-delivery-failure-notifications.json) | 6 | Published; recover/claim/send/complete/fail |
| 05 | [WhatsApp manual test](../workflows/05-whatsapp-api-test.json) | 2 | Manual, inactive; hello_world/en_US |
| 06 | [WhatsApp outbox](../workflows/06-whatsapp-failure-notifications.json) | 6 | Unpublished/inactive; `order_gateway_failure_alert`/en, three body text parameters; direct API acceptance PASS on 2026-10-13; scheduled workflow not run by that test |
| 07 | [Error alert](../workflows/07-workflow-error-alert.json) | 2 | Published; Error Trigger → Gmail |

The 2026-10-13 custom-template test returned **HTTP 200 — accepted** for the approved test number ending **2077** using the saved Module 06 request configuration directly. Both Modules 05/06 stayed unpublished, with no queue, code or configuration changes. API acceptance and actual phone delivery are **PASS**; the user confirmed receiving this test message on 2026-10-13. The test does not establish a new scheduled/outbox execution. Prior sending/completion/retry evidence is preserved in [Verified testing summary](QA-TEST-REPORT.md).

[Optional Odoo QA worker](../workflows/optional/02-odoo-qa-delivery-worker.json) retains the tested branch alongside mock routing. It is a replacement worker variant with fixture placeholders, not a default deployment or general Odoo adapter. See [Setup](SETUP.md) for import order, credential types and settings to rebind.

Sanitization removes credential names/IDs, instance workflow/version IDs, webhook IDs and error-handler references. Notification recipients and Meta phone-number identifiers become explicit nonworking placeholders; default mock URL uses Compose DNS `n8n`. SQL, Code validation/classification logic, node names/types/versions and internal connections remain intact except reviewed environment-placeholder substitutions in the optional QA branch. Original snapshots remain private/ignored, not deleted.

Module 01 returns 401 for invalid HMAC, 400 for signed invalid orders after persisted rejection, and 200 with accepted/duplicate/conflict database results for valid requests. It does not add a paid-only filter. The historical raw-body node may retain a test-oriented name; it is part of the functional signing/hash path and must not be removed solely because of its label.

Static validation checks JSON shape, unique node names/IDs, all connection targets, Code syntax and expression syntax, and unavailable external references. This establishes structurally importable exports, not a fresh-instance import/publication test. Error workflows require selection of your imported07; credentials and placeholders require configuration. Never activate notification modules merely to verify JSON import.

## Query-parameter compatibility

Module 04's published Fail Notification queryReplacement begins `=={{`. Installed PostgreSQL node2.7 removes all leading equals signs from string replacements before evaluating resolvables. Safe checks of the installed conversion operation returned the correct UUID/UUID/text/boolean array for synthetic503/401/400 errors. It is accepted node-specific syntax; no functional correction is needed. The public export retains it exactly, and the release checker accounts for this normalization. Historical Gmail workflow tests remain separate from this no-write parameter check.
