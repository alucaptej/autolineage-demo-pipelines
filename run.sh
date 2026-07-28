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

exec "$VENV_DIR/bin/spark-submit" \
  --packages io.acryl:acryl-spark-lineage:0.2.17,io.delta:delta-spark_2.12:3.3.2 \
  --properties-file conf/spark.conf \
  --conf "spark.datahub.rest.token=${DATAHUB_GMS_TOKEN:-}" \
  "$@" \
  "$JOB"
