# ADR-001 — n8n orchestration; PostgreSQL transaction boundary

**Status:** accepted and implemented. Original documentation date: 2026-10-11; reconciled 2026-10-12.

## Context

Accepting an order requires several related writes that must survive worker interruption. Separate n8n Postgres nodes cannot be assumed to form one transaction. The smaller integration must remain independent of the original API-based Order-Gateway.

## Decision

Use n8n to authenticate, validate, map, schedule and route external calls. Use a separate PostgreSQL business database for atomic acceptance and durable delivery/outbox state through controlled security-definer functions. Keep n8n's internal database separate from business tables on the same local PostgreSQL service.

## Consequences

Transaction/lease guarantees live in PostgreSQL; orchestration remains observable in n8n. Owner privileges, search paths and explicit function grants require review. HTTP calls occur outside database transactions. The default ERP is an n8n mock workflow plus SQL persistence; the optional Odoo JSON-2 branch is a controlled QA adapter.

## Verification

Atomic rollback, restricted worker access, scheduled mock reliability and one real draft quotation were verified. See [testing summary](../QA-TEST-REPORT.md). No architectural replacement of the original project is implied.
