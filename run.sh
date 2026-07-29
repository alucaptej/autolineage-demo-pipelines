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
export DATA_DIR="${DATA_DIR:-/private/tmp/lakehouse}"

# Emission endpoint. Pinned here (not only in conf/spark.conf) because the
# properties file is edited by operators and drifted to a dead port once,
# silently losing lineage for every run
# (incident urn:li:incident:23801a73-ddc4-40d5-8ee7-9bfc1b52e4dd).
DATAHUB_GMS_URL="${DATAHUB_GMS_URL:-http://localhost:8080}"

# Fail loudly rather than emitting into a black hole: a run that cannot reach
# GMS produces data but no lineage, which looks green everywhere. Set
# LINEAGE_PREFLIGHT=0 to run the job without lineage on purpose.
if [ "${LINEAGE_PREFLIGHT:-1}" = "1" ]; then
  if ! curl -fsS --max-time 5 -o /dev/null "$DATAHUB_GMS_URL/health"; then
    echo "run.sh: DataHub GMS unreachable at $DATAHUB_GMS_URL — lineage would be" >&2
    echo "  emitted into a dead endpoint and silently lost. Refusing to run." >&2
    echo "  Fix DATAHUB_GMS_URL (or the server), or set LINEAGE_PREFLIGHT=0 to" >&2
    echo "  run this job without lineage on purpose." >&2
    exit 1
  fi
fi

# The three emission properties are passed as --conf so they win over
# --properties-file (spark-submit flags outrank the properties file), keeping
# lineage correct even if conf/spark.conf drifts in a deployed checkout.
exec "$VENV_DIR/bin/spark-submit" \
  --packages io.acryl:acryl-spark-lineage:0.2.17,io.delta:delta-spark_2.12:3.3.2 \
  --properties-file conf/spark.conf \
  --conf spark.extraListeners=datahub.spark.DatahubSparkListener \
  --conf "spark.datahub.rest.server=$DATAHUB_GMS_URL" \
  --conf spark.datahub.metadata.dataset.materialize=true \
  --conf "spark.datahub.rest.token=${DATAHUB_GMS_TOKEN:-}" \
  "$@" \
  "$JOB"
