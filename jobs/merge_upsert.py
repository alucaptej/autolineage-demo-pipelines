"""Upsert raw_events into curated_events via Delta MERGE INTO."""

import os

from delta.tables import DeltaTable
from pyspark.sql import SparkSession


def data_dir() -> str:
    return os.environ.get("DATA_DIR", "data")


def ensure_curated(spark: SparkSession, curated_path: str) -> None:
    if not DeltaTable.isDeltaTable(spark, curated_path):
        empty = spark.createDataFrame(
            [], "event_id string, user_id string, event_type string, ts string"
        )
        empty.write.format("delta").mode("overwrite").save(curated_path)


def main() -> None:
    spark = SparkSession.builder.appName("merge_upsert_curated").getOrCreate()
    raw_path = f"{data_dir()}/raw_events"
    curated_path = f"{data_dir()}/curated_events"
    ensure_curated(spark, curated_path)

    raw = spark.read.format("delta").load(raw_path)
    curated = DeltaTable.forPath(spark, curated_path)
    (
        curated.alias("c")
        .merge(raw.alias("r"), "c.event_id = r.event_id")
        .whenMatchedUpdateAll()
        .whenNotMatchedInsertAll()
        .execute()
    )


if __name__ == "__main__":
    main()
    SparkSession.getActiveSession().stop()
