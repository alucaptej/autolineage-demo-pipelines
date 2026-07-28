---
name: datahub-lineage-debug
description: Diagnose broken or degraded Spark→DataHub lineage from live metadata evidence. Use when a lineage contract is violated — an expected dataset edge is missing, stale, or the graph grew unexpected duplicate entities.
---

# Debugging Spark lineage in DataHub

You are diagnosing why a Spark pipeline's lineage in DataHub no longer matches its
declared contract. Work from **live evidence**, not guesses: use the `datahub` MCP
tools (`search`, `get_lineage`, `get_entities`, `get_dataset_queries`,
`list_schema_fields`, `get_lineage_paths_between`) to observe the graph before
touching any code.

## Method

1. Read the violation you were given: expected downstream/upstream URNs, the run
   marker time, and the observed evidence bundle.
2. Pull the current picture yourself: `search` for the dataset basenames;
   `get_lineage` (upstream) on the expected downstream URN; `get_entities` on
   anything suspicious. Note **URN shapes** carefully — platform, name, env,
   platformInstance prefix.
3. Match the evidence against the failure modes below. State which signature fits
   and why; if none fits, STOP and escalate (see the last section).
4. The fix belongs in the pipeline repo (Spark conf, run wrapper, or job code) —
   never mutate DataHub metadata directly, never delete anything.
5. Your PR body MUST contain: the evidence you observed (URNs, timestamps), the
   signature you matched, the hypothesis you chose over the alternatives, and why
   the change repairs emission for future runs.

## Documented failure modes

### 1. Path fragmentation (duplicate URNs for one physical table)

**Signature**: `search` returns near-duplicate dataset URNs whose names are
relative/absolute variants or prefix-shifted versions of the same path (e.g.
`(file,data/curated_events,PROD)` alongside
`(file,/some/abs/path/curated_events,PROD)`). Fresh entities appeared at the last
run but the **canonical** URN's edge went stale. Root cause: the job resolves data
paths relative to its working directory (or an inconsistent base), so each launch
context mints different URNs. Fix class: make the data root absolute and stable in
the run configuration; the canonical URN shape in the contract tells you the
intended root.

### 2. Missing listener configuration (no emission plumbing)

**Signature**: NO DataFlow/DataJob entities exist for the pipeline at all, or they
stopped updating exactly when the Spark conf changed; job runs are green in CI.
Root cause: `spark.extraListeners=datahub.spark.DatahubSparkListener` (or the
whole lineage conf block) was removed/never applied to the run path that executes
in production. Fix class: restore the listener + `spark.datahub.rest.server` conf
in the properties actually used by the run entrypoint.

### 3. Missing dataset materialization (edges without entities)

**Signature**: `get_lineage` on the DataJob shows input/output dataset **edges**,
but `search` cannot find the dataset entities themselves (they 404 / don't
resolve). Root cause: `spark.datahub.metadata.dataset.materialize` is unset, so
the plugin references URNs without creating the entities. Fix class: set
`spark.datahub.metadata.dataset.materialize=true` in the Spark properties.

## If nothing matches — escalate, don't guess

If the evidence fits none of the documented signatures (for example: the run
marker says the pipeline executed, but there are **zero fresh emissions of any
kind** — no new entities, no updated timestamps, no fragments), do NOT open a
repair PR on a hypothesis you cannot support from evidence. Call `work_finish`
with `status: "blocked"` and a `blockers` entry describing exactly what you
observed and what a human should check (network path to the DataHub endpoint,
credentials, server health). A wrong confident fix is worse than a clean
escalation.
