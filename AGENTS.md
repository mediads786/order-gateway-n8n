# Evidence and publication rules

Read `docs/QA-TEST-REPORT.md`, `docs/NOTIFICATION-VERIFICATION.md` and `SECURITY.md` before judging claims or publishing. The owner reports WhatsApp activation and testing after Meta template approval. Preserve that historical verification separately from the later inactive workflow snapshot. Do not infer an earlier test never happened from the current active flag.

The Python API is a separate implementation. Its canonical evidence summary and dated publication audit are linked in `SECURITY.md`. Do not import notification features into API claims or rewrite its real Shopify-to-Odoo test as synthetic-only.

Before each commit/upload, enumerate and inspect the complete proposed files and staged diff, run redacted secret and private-address checks, and visually inspect all new images/recordings and metadata. Publish sanitized workflow exports only: no credential bindings, pinned data, workflow/execution identifiers, customer contact details, provider account IDs, access tokens, private keys, raw environment files, database dumps, live deployment addresses or private QA originals. Never force-add ignored archives. Ignore rules and scanner passes do not prove zero risk.

Use the dated retained evidence before proposing repeat tests. Re-test only for a relevant change, failure or unresolved question. Do not activate workflows, send/retry orders, send notifications, rotate credentials or change services merely to reconcile documentation.
