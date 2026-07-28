#!/usr/bin/env bash
# Run a pipeline job with lineage emission: ./run.sh jobs/merge_upsert.py
# Requires: .venv (pyspark), JAVA_HOME, DATAHUB_GMS_TOKEN in env.
set -euo pipefail
cd "$(dirname "$0")"

JOB="${1:?usage: ./run.sh jobs/<job>.py [extra spark-submit args...]}"
shift || true

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"
export PATH="$JAVA_HOME/bin:$PATH"
export PYSPARK_PYTHON="$PWD/.venv/bin/python"
export PYSPARK_DRIVER_PYTHON="$PWD/.venv/bin/python"

# Absolute data root keeps dataset URNs canonical — relative paths fragment the
# lineage graph into duplicate entities (one URN per working directory).
export DATA_DIR="${DATA_DIR:-/private/tmp/lakehouse}"

exec .venv/bin/spark-submit \
  --packages io.acryl:acryl-spark-lineage:0.2.17,io.delta:delta-spark_2.12:3.3.2 \
  --properties-file conf/spark.conf \
  --conf "spark.datahub.rest.token=${DATAHUB_GMS_TOKEN:-}" \
  "$@" \
  "$JOB"
