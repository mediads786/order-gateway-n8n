# ADR-002 — Atomic intake and separate replay identities

**Status:** accepted and implemented with explicit limits. Original documentation date: 2026-10-11; reconciled 2026-10-12.

## Context and decision

A webhook delivery identity differs from a business-order identity. Enforce unique store/webhook receipts, unique store/Shopify-order records and one delivery job per order. Serialize acceptance with an order-level advisory transaction lock; persist order, all lines, job, receipt and audit atomically. Preserve a stable ERP external reference.

## Consequences

Identical webhook replay creates no new receipt/audit/job. A new delivery ID for identical order JSON creates a duplicate receipt/audit only. Changed orders/create payload conflicts rather than silently replacing an accepted order. Original SKU and raw source values remain local. No paid-only filtering was added; the paid real order was a fixture choice.

## Limits and verification

SQL rollback/concurrency, eight actual overlapping signed requests and real Shopify replay verified the tested identities. Acceptance/rejection use different advisory lock keys; mixed-path races remain unverified. This is not orders/updated support. Money/line totals, shipping/discount/tax equivalence and all validation boundaries require broader verification before production. See [testing summary](../QA-TEST-REPORT.md).
