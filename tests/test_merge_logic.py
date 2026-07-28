"""Merge-logic tests on plain local Spark — no lineage listener, no DataHub.

Jobs call SparkSession.builder...getOrCreate(), so they reuse the
delta-enabled session created here; job code needs no test hooks.
"""

import os
import sys
from pathlib import Path

import pytest

os.environ.setdefault("PYSPARK_PYTHON", sys.executable)
os.environ.setdefault("PYSPARK_DRIVER_PYTHON", sys.executable)
from delta import configure_spark_with_delta_pip
from pyspark.sql import SparkSession

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from jobs import merge_upsert, seed_raw  # noqa: E402


@pytest.fixture(scope="module")
def spark():
    builder = (
        SparkSession.builder.master("local[1]")
        .appName("tests")
        .config("spark.ui.enabled", "false")
        .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
        .config(
            "spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog",
        )
    )
    session = configure_spark_with_delta_pip(builder).getOrCreate()
    yield session
    session.stop()


def test_seed_then_merge_upserts_all_rows(spark, tmp_path, monkeypatch):
    monkeypatch.setenv("DATA_DIR", str(tmp_path / "data"))

    seed_raw.main()
    merge_upsert.main()
    merge_upsert.main()  # re-run must be idempotent (upsert, not append)

    curated = spark.read.format("delta").load(str(tmp_path / "data" / "curated_events"))
    assert curated.count() == 4
    assert curated.filter("event_id = 'e3'").first()["event_type"] == "purchase"
