# Architecture decision records

| ADR | Decision | Current state |
|---|---|---|
| [001](001-n8n-postgres-split.md) | n8n orchestration; PostgreSQL transaction boundary | Implemented |
| [002](002-atomic-intake-idempotency.md) | Atomic intake and separate replay identities | Implemented; mixed acceptance/rejection race remains unverified |
| [003](003-job-delivery-design.md) | Durable claims, retry and recovery | Implemented and mock workflow-tested |
| [004](004-erp-idempotency.md) | Stable ERP reference and uncertain outcomes | Mock reconciliation tested; narrow Odoo QA verified, broader external limits remain |

Original decision dates are retained. [Architecture](../ARCHITECTURE.md) and [verified testing summary](../QA-TEST-REPORT.md) define the current implementation and verification boundary.
