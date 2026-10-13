# ADR-004 — Stable ERP references and uncertain outcomes

**Status:** implemented and verified for mock reconciliation; narrow real Odoo delivery/replay verified. Original documentation date: 2026-10-11; reconciled 2026-10-12.

## Context and decision

An ERP can create an order before the gateway receives its response. Reuse the stable external_reference on retries. The default mock POST handler enforces a unique reference and returns the existing ID for identical payloads; it does not need a separate pre-create lookup. The Odoo QA branch first searches client_order_ref, checks fixture mapping, creates only if absent and validates draft-order/line readback before local completion.

## Superseded proposal details

The earlier proposed/unimplemented status is superseded by migration009, Modules 02/03 and the optional Odoo branch. Generic lookup-before-create describes Odoo, not the mock's atomic POST contract. The controlled Odoo test is draft-only; confirmation, customer creation and stock/accounting operations were not adopted.

## Verification and limits

Actual post-create mock interruption reconciled to the same ID. One real Shopify #1018 became Odoo draft S00048; exact webhook replay created no additional quotation. Odoo lookup-before-create is not atomic external uniqueness, and real Odoo unknown-outcome/concurrent-create faults were not tested. A general product/customer/tax adapter is outside this smaller scope. See [testing summary](../QA-TEST-REPORT.md).
