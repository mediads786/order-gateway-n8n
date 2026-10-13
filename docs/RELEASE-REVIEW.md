# Public release checklist and documentation inventory

Reconciled 2026-10-12 against actual SQL migrations, Compose configuration, current exports, published Module 04 and final verified outcomes. Updated 2026-10-13 to record the existing custom WhatsApp template acceptance evidence; no tests were rerun for this documentation update. This is the current release assessment; full internal QA history is private.

## Complete reviewed inventory

| File reviewed | Reconciliation |
|---|---|
| ../README.md | Current business value, verified results, default mock/optional Odoo distinction and public summary links |
| ARCHITECTURE.md | Actual module connections, persistent state/leases/backoff, privilege boundary and node compatibility |
| DATA_MODEL.md | All eight business tables and migrations001–013; core SELECT/function grant distinction |
| OPERATIONS.md | Actual privileged recovery, notification isolation, persistence/backup limitations |
| SETUP.md | Docker/business bootstrap/import order; protect existing .env; verified Module 04 compatibility |
| TESTING.md | Reproduction procedures, layer separation, current public-summary/private-log policy |
| TEST_PLAN.md | Replaced obsolete intake-only checkpoint with current regression plan |
| QA-TEST-REPORT.md | Public final-results summary; original full report preserved privately, unchanged |
| WORKFLOW_DESIGN.md | Modules 00–07 and optional Odoo inventory; source/sanitization and compatibility boundaries |
| RELEASE-REVIEW.md | Current public checklist; original review privately preserved |
| adr/README.md | Current implemented/superseded decision index |
| adr/001-n8n-postgres-split.md | Preserve transaction split and rationale; completed scheduling/QA boundary |
| adr/002-atomic-intake-idempotency.md | Preserve delivery/order identity rationale; replay/conflict semantics and current scope |
| adr/003-job-delivery-design.md | Supersede proposed status/jitter; document shipped deterministic backoff and verified mock recovery |
| adr/004-erp-idempotency.md | Distinguish atomic mock POST from Odoo lookup-before-create; supersede unimplemented/general confirmation assumptions |
| qa-preparation/module-01-before-live.json | Reviewed preparation snapshot; preserved privately, removed from public docs |
| qa-preparation/module-01-live-DRAFT.json | Reviewed preparation snapshot; preserved privately, removed from public docs |
| qa-preparation/module-02-before-odoo.json | Reviewed rollback snapshot; preserved privately, removed from public docs |
| qa-preparation/module-02-odoo-qa-DRAFT.json | Reviewed tested branch source; private original, sanitized public optional equivalent |
| qa-preparation/shopify-order-1018-proof.png | Actual cropped Shopify proof inspected; no customer/contact information; retained publicly |

All files that existed under docs at audit start were reviewed, including non-Markdown preparation artifacts. No older plan/ADR was skipped. There were no additional release-note files.

## Public/private boundary

Public: current documentation, concise [testing summary](QA-TEST-REPORT.md), cropped screenshot, sanitized Modules 01–07 (plus optional00/Odoo), all13 migrations, Compose, synthetic fixtures and release checker. The mock implementation is Module 03 plus migration009, not a separate missing service.

Private: byte-identical original full QA report, all pre-reconciliation documents, unsanitized preparation/rollback snapshots and original checker are retained under the ignored .private archive. Archive integrity was verified with SHA-256. Internal failures/debugging/attempt chronology are not public documentation. The existing unsanitized workflows-export directory remains ignored and preserved. Do not force-add private files.

## Module 04 compatibility conclusion

Read-only inspection confirmed the current published Fail Notification node uses PostgreSQL 2.7 and queryReplacement begins `=={{`. Its installed executeQuery operation strips leading equals signs with replace(/^=+/, '') when converting string query replacements. Safe invocation using the installed default VM engine, real workflow data proxy and a stubbed runQueries callback produced exactly four typed values and the expected true/false/false retry flags for503/401/400. No database query, workflow execution or notification send occurred.

Conclusion: accepted node-specific configuration; the previous generic checker warning was a false positive. The checker now models this normalization for PostgreSQL queryReplacement rather than altering exports or the working instance. A new full Gmail failure regression was not run; retained actual executions190/191/197 remain the historical branch evidence. No functional correction is required for this prefix.

## Custom WhatsApp template checkpoint — 2026-10-13

**PASS for API acceptance:** Meta returned **HTTP 200 — accepted**, a message ID and `message_status: accepted` for `order_gateway_failure_alert` / `en`, three synthetic body parameters, to the approved test number ending **2077**. Both Modules **05/06 remained unpublished/inactive**. No queue, code or configuration changes were made by the test. It used the saved request configuration directly and did not run the scheduled outbox workflow.

**Actual phone delivery: PASS — user confirmed receipt.** On 2026-10-13 the user confirmed receiving this custom-template test message on the approved test number ending2077. The evidence is the user's handset receipt confirmation; no independent Meta delivery-status webhook receipt was captured. This supersedes the earlier unconfirmed status. Custom-template API acceptance and phone delivery are verified for this test. Prior Gmail, WhatsApp outbox, Shopify-to-Odoo, replay and mock reliability results are preserved in [Verified testing summary](QA-TEST-REPORT.md).

Only local documentation was updated; no new tests, tunnel/token requests, workflow modifications, commit or GitHub push were performed.

## Release verification and remaining limits

- Workflow shape/connections/reference checks, Code/expression syntax, export fingerprints and local Markdown targets are checked by `node scripts/verify-release.js`. This does not establish fresh-instance import/runtime compatibility.
- Compose syntax is checked without starting/restarting services. Business initialization requires separate role/database provisioning before migrations001–013; no automatic initialization mount or migration ledger exists.
- Public exports contain no credential bindings/pinned data/local workflow IDs. Placeholder recipients and Meta identifiers require operator configuration; optional Odoo fixture IDs/database/domain/host require review.
- Private .env, archives, logs, volume/database state and original snapshots are ignored. Scanned token/private-key patterns and exact local .env secret values are not present in public candidate files. Scans are scoped rather than a guarantee against every possible secret format.
- Local Git was initialized on `main` for the 2026-10-13 initial publication. Only the reviewed public inventory is selected for the initial commit; private files are excluded by Git rules and never force-added. Historical no-Git statements below describe earlier verification checkpoints.
- Clean-volume bootstrap was verified on 2026-10-13; fresh workflow import and backup restore remain untested. Fault proxies/one-off QA harnesses are not shipped. Broader real Odoo faults/concurrent creation and mixed intake accept/reject races remain unverified.
- Custom WhatsApp failure-template API acceptance is **PASS** (HTTP 200 — accepted, 2026-10-13). Actual phone delivery is **PASS — user confirmed receipt** on 2026-10-13. Module 06 permanent-error classification remains unverified, and this direct API test adds no scheduled/outbox regression coverage.
- The n8n image is pinned to the tested 2.42.6; PostgreSQL 16 and Odoo 19 were tested, and newer versions are not established. An MIT LICENSE is present in the project; it was not changed by this documentation update.

## Assessment

**Ready for final GitHub review and portfolio demonstration with documented limitations.** No confirmed blocking defect remains from this documentation reconciliation. Perform final owner review and audit any existing remote history before publication. The project already contains an MIT LICENSE. Custom-template API acceptance and user-confirmed phone delivery are no longer outstanding blockers. The remaining verification limits above still prevent broader delivery or production-readiness claims. Do not describe the project as production-certified. No application logic, SQL, Docker configuration, credentials or running service behavior was changed.


## Historical final static verification results

The following results are retained from the earlier release review. They were not rerun for the 2026-10-13 WhatsApp documentation update; counts refer to that earlier checkpoint.

PASS: nine exports, 24 Code bodies and 53 normal/normalized expressions compile; all 50 local Markdown targets exist; all standard and optional export fingerprints match. All eight standard exports match fresh published/saved definitions after documented sanitization; the optional Odoo export matches its privately retained source. All 21 archived originals match their recorded SHA-256 hashes. Protected workflow JSON, migrations, Compose and synthetic fixtures are unchanged. Forty-five public candidate files were scanned with no local .env-secret or known-token match. PowerShell documentation snippets parse; Compose syntax passes. Git-ignore probes confirm private archives/secrets/raw exports excluded and public sources/summary/screenshot retained. No Git repository was initialized in the project or for this audit; an existing external scratch checker was reused.
## Final milestone release verification — 2026-10-13

Scope: release packaging, existing static checks, secret scanning and read-only verification of retained evidence. No additional feature development, new business QA, live workflow edits, external test orders or notification sends were performed.

- **Existing release checker: PASS.** Nine sanitized workflows (00–07 plus optional Odoo), 24 Code bodies and 53 normal/normalized expressions compile; export manifest fingerprints and local documentation links pass. The earlier Module 04 prefix finding remains resolved as documented above.
- **Public inventory:** nine workflow exports plus their manifest, all migrations 001–013, Compose, placeholder-only `.env.example`, the Module 03/migration 009 mock ERP implementation, the existing release-check script, synthetic JSON/SQL test fixtures, all current public documentation, the reviewed cropped Shopify proof, MIT LICENSE, `.gitignore` and `.gitattributes`. Historical fault proxies and one-off QA harnesses remain outside the supplied runnable artifacts, as documented in TESTING.md.
- **Secret and exclusion checks: PASS.** The existing scan logic found no local `.env` secret values or known provider-token/private-key/bearer patterns in the reviewed public candidates. Git rules exclude `.private/`, `.env`, original `workflows-export/`, credential stores, local database/n8n state, backups and logs. `.env.example` is intentionally public and contains nonworking placeholders. The screenshot contains no customer/contact data. The exact Git index is inspected and scanned before committing.
- **Source integrity:** all 25 archived protected-source fingerprints were reviewed. The sole difference is Compose's previously documented change from the moving `stable` tag to the tested `2.42.6` tag; reversing that single substitution reproduces its archive hash. Workflow exports, migrations and synthetic fixtures retain their archived bytes. The old archive comparison is therefore not a new functional defect. Git attributes preserve workflow bytes so checkout line-ending conversion cannot invalidate manifest hashes.
- **Runtime/evidence readback: PASS.** The current published Module 02 remains active and routes to mock ERP. Retained Shopify #1018 records show delivered/succeeded, attempt 1 and Odoo ID15; executions 1131/1132/1135 remain successful. The documented real Shopify → n8n → PostgreSQL → Odoo draft-quotation test and exact replay remain verified, while the default route remains mock.
- **WhatsApp: PASS.** `order_gateway_failure_alert` / `en` returned HTTP 200 — accepted for the approved test number ending2077; the user confirmed handset receipt. Both Modules 05/06 remained unpublished during that test. A new scheduled/outbox regression and an independent delivery-status webhook receipt are not claimed.
- **License: MIT.** The existing LICENSE was inspected and preserved byte-for-byte; README links to it. No license was invented or replaced.
- **Security review:** 256 published n8n advisory version ranges were checked against pinned version 2.42.6, with no matching affected range or unparsed range. Source: [n8n maintainer security advisories](https://github.com/n8n-io/n8n/security/advisories). Local-only port binding, credential-free public exports, HMAC intake and controlled SQL functions match the documented demonstration boundary. No known unresolved blocker was identified for the advertised local portfolio demonstration. This scoped review does not certify production deployment or every transitive container dependency.

**Milestone assessment: ready for initial public GitHub publication under `mediads786/order-gateway-n8n`.** Previously documented limitations remain: fresh-instance workflow import, backup restore, broader real Odoo faults/concurrent creation, mixed intake error/concurrency cases and permanent Meta-error handling. They are not presented as verified capabilities and were not expanded for this release.
