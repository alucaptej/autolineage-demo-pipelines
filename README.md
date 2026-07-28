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
./run.sh jobs/seed_raw.py
./run.sh jobs/merge_upsert.py
```

## License

[Apache-2.0](./LICENSE)
<!-- wg-gate4-probe -->
