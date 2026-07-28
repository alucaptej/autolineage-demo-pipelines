"""Seed the raw_events Delta table with sample click events."""

import os

from pyspark.sql import SparkSession


def main() -> None:
    spark = SparkSession.builder.appName("seed_raw_events").getOrCreate()
    data_dir = os.environ.get("DATA_DIR", "data")
    rows = [
        ("e1", "user_1", "click", "2026-07-28T10:00:00"),
        ("e2", "user_2", "view", "2026-07-28T10:01:00"),
        ("e3", "user_1", "purchase", "2026-07-28T10:02:00"),
        ("e4", "user_3", "click", "2026-07-28T10:03:00"),
    ]
    df = spark.createDataFrame(rows, ["event_id", "user_id", "event_type", "ts"])
    df.write.format("delta").mode("overwrite").save(f"{data_dir}/raw_events")


if __name__ == "__main__":
    main()
    SparkSession.getActiveSession().stop()
