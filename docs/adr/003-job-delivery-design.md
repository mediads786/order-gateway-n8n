# ADR-003 — Durable claims, retries and recovery

**Status:** accepted and implemented for the default mock path. Original documentation date: 2026-10-11; reconciled 2026-10-12.

## Context and decision

Scheduled workers can overlap or crash while an external call is in progress. Use FOR UPDATE SKIP LOCKED to claim due jobs, increment attempts and issue fresh UUID leases. Only current owners may complete/fail a job. Persist transitions and audits; keep HTTP calls outside claim transactions.

Use deterministic exponential retry deadlines, base2 seconds, cap60 seconds, max5 attempts by default. Exhausted/permanent failures become durable dead letters. Recover processing leases older than120 seconds; privileged manual requeue resets a reviewed dead job with an audit reason. The worker cannot invoke manual recovery.

## Superseded proposal details

The earlier unimplemented/proposed status is superseded by migrations004–008 and actual worker QA. The proposed jitter is not in the shipped SQL; current delays are deterministic. The minute schedule processes eligible jobs after their deadline rather than precisely at the backoff duration.

## Verification and limits

Actual mock tests verified transient retries, exhaustion, manual recovery, overlapping workers and post-create crash recovery; SQL tests separately verified stale-token rejection. Leases protect local state, not exactly-once external effects. Real Odoo fault/concurrent-create behavior remains unverified. See [testing summary](../QA-TEST-REPORT.md).
