#!/usr/bin/env bash
# Run a pipeline job with lineage emission: ./run.sh jobs/merge_upsert.py
# Requires: .venv (pyspark), JAVA_HOME, DATAHUB_GMS_TOKEN in env.
set -euo pipefail
cd "$(dirname "$0")"

JOB="${1:?usage: ./run.sh jobs/<job>.py [extra spark-submit args...]}"
shift || true

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
export PATH="$JAVA_HOME/bin:$PATH"
# VENV_DIR override lets verification checkouts (fresh clones without .venv)
# borrow an existing environment.
VENV_DIR="${VENV_DIR:-$PWD/.venv}"
export PYSPARK_PYTHON="$VENV_DIR/bin/python"
export PYSPARK_DRIVER_PYTHON="$VENV_DIR/bin/python"

# Absolute data root keeps dataset URNs canonical — relative paths fragment the
# lineage graph into duplicate entities (one URN per working directory).
# Must stay in sync with expectations.json "data_root"
# (incident urn:li:incident:24efa153-a224-4648-afda-8fa8f777db50).
export DATA_DIR="${DATA_DIR:-data}"

# The lineage emission endpoint is owned by this entrypoint, not by
# conf/spark.conf: a stale or locally edited spark.datahub.rest.server makes
# DatahubSparkListener drop every emission while the Spark job still exits 0,
# so the pipeline reports green and the graph silently goes stale
# (incident urn:li:incident:8ce039bd-1b15-4609-a7a3-af0237772c93).
# spark-submit resolves duplicate --conf keys last-wins and --conf outranks
# --properties-file, so this pin defeats any drift in the properties file.
GMS_URL="${DATAHUB_GMS_URL:-http://localhost:8080}"

# Fail closed: if the endpoint is unreachable the run would emit nothing and
# still succeed. Better to stop loudly than to ship a silent lineage gap.
if [ "${DATAHUB_EMIT_PRECHECK:-1}" != "0" ]; then
  if ! command -v curl >/dev/null 2>&1; then
    echo "run.sh: curl not found — skipping DataHub reachability precheck" >&2
  elif ! curl -fsS --max-time 5 "${GMS_URL%/}/health" >/dev/null 2>&1; then
    echo "run.sh: DataHub GMS at $GMS_URL is unreachable; lineage emission would be" >&2
    echo "        dropped silently while the job exits 0. Refusing to run." >&2
    echo "        Set DATAHUB_GMS_URL=<reachable gms> or DATAHUB_EMIT_PRECHECK=0" >&2
    echo "        to run without lineage emission." >&2
    exit 1
  fi
fi

echo "run.sh: lineage endpoint $GMS_URL" >&2

exec "$VENV_DIR/bin/spark-submit" \
  --packages io.acryl:acryl-spark-lineage:0.2.17,io.delta:delta-spark_2.12:3.3.2 \
  --properties-file conf/spark.conf \
  --conf "spark.datahub.rest.token=${DATAHUB_GMS_TOKEN:-}" \
  --conf "spark.datahub.rest.server=$GMS_URL" \
  "$@" \
  "$JOB"
