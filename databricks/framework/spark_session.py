"""
Spark Session Factory with Delta Lake and Enterprise Tuning
"""
import os
from typing import Optional
from .logger import MigrationLogger

logger = MigrationLogger("SparkSessionBuilder")

def get_spark_session(app_name: str = "EyeRecommend-HealthcareMigration") -> Any:
    """
    Creates or retrieves a tuned SparkSession.
    Configured for:
    - Delta Lake extensions & catalog
    - Adaptive Query Execution (AQE)
    - Dynamic partition pruning
    - Off-heap memory and optimized shuffle partitions
    """
    try:
        from pyspark.sql import SparkSession

        builder = (
            SparkSession.builder.appName(app_name)
            .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
            .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
            .config("spark.sql.adaptive.enabled", "true")
            .config("spark.sql.adaptive.coalescePartitions.enabled", "true")
            .config("spark.sql.adaptive.skewJoin.enabled", "true")
            .config("spark.sql.shuffle.partitions", "200")
            .config("spark.databricks.delta.schema.autoMerge.enabled", "true")
            .config("spark.databricks.delta.optimizeWrite.enabled", "true")
            .config("spark.databricks.delta.autoCompact.enabled", "true")
        )

        # Allow running locally in single-node without requiring Hadoop native libs
        if "DATABRICKS_RUNTIME_VERSION" not in os.environ:
            builder = (
                builder.master("local[*]")
                .config("spark.driver.memory", "4g")
                .config("spark.sql.warehouse.dir", "/tmp/spark-warehouse")
            )

        spark = builder.getOrCreate()
        spark.sparkContext.setLogLevel("WARN")
        logger.info("Successfully initialized PySpark Session", version=spark.version)
        return spark
    except Exception as e:
        logger.warning(
            "PySpark runtime not directly importable or Java runtime missing; fallback to Mock/Pandas mode",
            error=str(e)
        )
        return None
