# Incident Diagnosis — `ActiveRecord::RecordNotUnique` on `traces` (Observability)

> **STATUS: UNVERIFIED — needs DB/deploy confirmation.**
> This document is a diagnosis only. No code or schema change is shipped, because the
> root cause **could not be verified against the live database**. See "Why this is
> unverified" below. Do **not** merge a migration or code change based on this document
> until the confirmation steps have been run.

## Alert

| Field | Value |
|---|---|
| Source | reflex (Observability) |
| Event | `error` / `new error` |
| Error class | `ActiveRecord::RecordNotUnique` |
| Message | `PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint "index_traces_on_trac..."` (truncated) |
| Fingerprint | `cbab5bbaa9dde35c` |
| Error group | `836bae20-0761-4dae-b939-122c20af8faa` |
| Project id | `6e130615-079b-440a-b7f9-c4c48b42f52f` |
| Environment | production |
| Occurred | 2026-06-16 17:13:59 UTC |
| reflex URL | https://reflex.brainzlab.ai/error_groups/836bae20-0761-4dae-b939-122c20af8faa |

## Why this is unverified (what I tried)

The triage protocol requires confirming live state before proposing a fix. I could **not**
confirm it:

1. **No database credential for this product.** `vault_db_query action:list_credentials`
   returns only: `amplifica-db-ro, bite-db-ro, browq-db-ro, doiteveryday-db-ro,
   nexus-db-ro, propi-db-ro, sinfiltro-db-ro, sondea-db-ro, synapse-db-ro`. There is **no
   `observability-db-ro`** (the credential the runbook expected). I therefore cannot
   inspect the `traces` table, its indexes, or its data.
2. **No accessible DB even contains a `traces` table.** I ran `list_tables` against all 9
   available credentials as a sanity check — none has a `traces` table, so the violation
   is not happening in any database I can reach.
3. **The `traces` table is not in this product's source.** Neither `recall` nor `reflex`
   defines a `traces` table or `Trace` model anywhere in history. `recall` stores
   telemetry in `log_entries`; `reflex` stores `error_groups` / `error_events`. The
   constraint `index_traces_on_trace_id` does not exist in `db/schema.rb`,
   `db/structure.sql`, or any migration on `main`. This means **production is running code
   not present on `main`** (the `recall` `db/schema.rb` is already stale — pinned at
   version `2025_12_23_200000` while migrations exist through `2026_03_05`), so the
   relevant code path cannot be located or fixed from this checkout.
4. **The error group is not reachable via the reflex MCP** (`reflex_show` /
   `reflex_search` for this fingerprint/class return "not found" / empty — the MCP key is
   scoped to a different project), and `recall` log queries timed out, so I could not pull
   the backtrace to pinpoint the insert site.

Because the product has no DB credential and the offending table/code is absent from this
repo, **inventing a migration or code edit here would be a plausible-but-wrong fix.** This
document is the deliverable instead.

## Most likely root cause (hypothesis)

`index_traces_on_trace_id` is (almost certainly) a **UNIQUE** index on a `traces` /
spans table, and the trace-ingestion path performs a **non-idempotent insert** of a
`trace_id` that already exists. Under at-least-once delivery, client retries, or
concurrent ingestion workers, the same `trace_id` arrives twice; the second `INSERT`
violates the unique index and raises `PG::UniqueViolation` → `ActiveRecord::RecordNotUnique`.

This matches the **idempotency idiom used throughout the Observability stack today**, which
is race-prone and does not rescue `RecordNotUnique`:

- `recall` — `app/controllers/api/v1/ingest_controller.rb` inserts telemetry with plain
  `create!` and raw `INSERT INTO ... VALUES (...)` (no `ON CONFLICT` clause). An analogous
  traces ingestion path built this way is **not** safe against duplicate `trace_id`s.
- `reflex` — `app/services/error_processor.rb:32` uses
  `find_or_create_by!(fingerprint:)` on a unique column. `find_or_create_by!` does
  `SELECT` then `INSERT`; two concurrent requests can both miss the `SELECT` and both
  `INSERT`, so the loser raises `RecordNotUnique`. The same pattern applied to
  `traces.trace_id` produces exactly this alert.

Less likely (rule out via the steps below):

- **Index is over-scoped.** If `trace_id` is only meant to be unique *per project* but the
  index is global (`UNIQUE (trace_id)` instead of `UNIQUE (project_id, trace_id)`), two
  projects sharing a `trace_id` collide. This would be a schema fix (migration), **not** an
  ingestion fix — confirm with the index definition before choosing.
- A backfill / replay job re-inserting historical traces without conflict handling.

## Confirmation steps (run by a human with Observability DB + repo access)

```sql
-- 1. Confirm the table and the exact index (name was truncated in the alert).
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'traces';
\d traces

-- 2. Is the unique key global or per-project? (decides ingestion-fix vs schema-fix)
--    Look for whether the unique index includes project_id.

-- 3. Are duplicate trace_ids actually present / being attempted?
SELECT trace_id, count(*) FROM traces GROUP BY trace_id HAVING count(*) > 1 LIMIT 20;
```

```bash
# 4. Find the insert site in the ACTUAL deployed code (not on main):
#    deploy/SHA of the running Observability service, then:
grep -rniE "class Trace|create_table[ :\"']+traces|index_traces|\.traces\.create|INSERT INTO traces" .

# 5. Pull the full backtrace for the error group to confirm the call site:
#    https://reflex.brainzlab.ai/error_groups/836bae20-0761-4dae-b939-122c20af8faa
```

## Fix that would follow (do NOT apply until confirmed)

- **If the unique index is correct and the bug is the non-idempotent write (most likely):**
  make trace ingestion idempotent. Either
  - `INSERT INTO traces (...) VALUES (...) ON CONFLICT (trace_id) DO NOTHING` (or
    `DO UPDATE` if late fields should win), using the matching conflict target, or
  - rescue the race: `find_or_create_by!(trace_id:)` wrapped to
    `rescue ActiveRecord::RecordNotUnique; retry`/return the existing row.
  This is a **code** fix, **not** a new migration — the unique constraint is intended.
- **If the index is over-scoped** (trace_id should be unique per project): replace it with
  `UNIQUE (project_id, trace_id)` via a migration. Only choose this if step 2 proves the
  current index is global and cross-project collisions are real.

## What was NOT done and why

No migration, schema edit, or ingestion code change was made: the offending table/code is
not in this repository and there is no DB credential for the Observability product, so any
concrete fix would be unverifiable guesswork. Confirm with the steps above first, then ship
the matching fix in the repo/SHA that actually defines `traces`.
