# autolineage-demo-pipelines

A small PySpark + Delta Lake pipeline that serves as the repair target for
[AutoLineage](https://github.com/alucaptej/autolineage) — the self-healing-lineage agent
built for the DataHub Agent Hackathon. The agent opens CI-tested pull requests against
this repo; its merged PRs are visible in the history.

## Layout

- `jobs/seed_raw.py` — seeds the `raw_events` Delta table
- `jobs/merge_upsert.py` — `MERGE INTO curated_events` upsert (the lineage-relevant job)
- `conf/spark.conf` — Spark properties incl. DataHub lineage emission (the file the agent fixes)
- `expectations.json` — the lineage contract AutoLineage enforces
- `run.sh` — `spark-submit` wrapper (lineage jar + properties file; token from env)
- `tests/` — merge-logic tests on plain local Spark (no DataHub needed)

## Run locally

```sh
python3.12 -m venv .venv
.venv/bin/pip install "pyspark==3.5.6" "delta-spark==3.3.2" ruff pytest
export DATAHUB_GMS_TOKEN=...   # personal access token for your DataHub
export DATAHUB_GMS_URL=...     # optional, defaults to http://localhost:8080
./run.sh jobs/seed_raw.py
./run.sh jobs/merge_upsert.py
```

`run.sh` owns the lineage emission endpoint (`spark.datahub.rest.server`) and pins it
over `conf/spark.conf`, so a drifted properties file cannot silently mute emission. It
also refuses to launch when that endpoint is unreachable — a run that cannot emit
lineage fails loudly instead of reporting green. Set `DATAHUB_EMIT_PRECHECK=0` to skip
that probe for offline/dev runs.

## How AutoLineage repairs this repo

This repo is the *patient*. [AutoLineage](https://github.com/alucaptej/autolineage)
enforces `expectations.json` against the live DataHub graph after every pipeline run
(the Makefile pokes its run marker, standing in for a scheduler post-run hook). When a
run violates the contract, the agent investigates via the DataHub MCP server using the
playbook in `skills/datahub-lineage-debug/SKILL.md`, and ships its fix as a PR here —
CI-gated, validated pre-merge in an isolated DataHub namespace, merged by exact SHA.
[PR #1](https://github.com/alucaptej/autolineage-demo-pipelines/pull/1) is such an
agent-authored merge.

Demo mechanics: `make run` (healthy), `make break` (plausible regression + broken run),
`make reset-data`.

## License

[Apache-2.0](./LICENSE)
<!-- wg-gate4-probe -->
