# Databricks notebook source
# MAGIC %md
# MAGIC # Eye Recommend Healthcare Data Migration Runner
# MAGIC ### Interactive Control, Validation & Telemetry Dashboard
# MAGIC 
# MAGIC This notebook provides interactive controls for:
# MAGIC 1. Ingesting legacy Drupal MariaDB clinical records and Salesforce CRM objects.
# MAGIC 2. Running HIPAA Safe Harbor masking and automated data quality audits.
# MAGIC 3. Harmonizing Master Patient Index (MPI) and domain models.
# MAGIC 4. Bulk-loading into Azure Database for PostgreSQL Flexible Server.

# COMMAND ----------
# Widget setup for parameterization
dbutils.widgets.text("batch_id", "MANUAL-RUN-001", "Batch Identifier")
dbutils.widgets.dropdown("environment", "prod", ["dev", "staging", "prod"], "Environment")
dbutils.widgets.dropdown("migration_phase", "PRODUCTION_CUTOVER", ["HISTORICAL_INIT", "INCREMENTAL_CATCHUP", "PRODUCTION_CUTOVER"], "Phase")

batch_id = dbutils.widgets.get("batch_id")
env = dbutils.widgets.get("environment")
phase = dbutils.widgets.get("migration_phase")

print(f"Executing migration batch: {batch_id} in {env} for phase {phase}")

# COMMAND ----------
# MAGIC %md
# MAGIC ## Step 1: Initialize Spark Session & Key Vault Secrets

# COMMAND ----------
import sys
import os
from databricks.framework.spark_session import get_spark_session
from databricks.framework.vault_helper import KeyVaultManager
from databricks.framework.logger import MigrationLogger

logger = MigrationLogger("DatabricksInteractiveRunner", batch_id=batch_id)
vault = KeyVaultManager()
spark = get_spark_session("EyeRecommendMigration")

logger.info("Successfully connected to Azure Key Vault & Delta Lake Engine")

# COMMAND ----------
# MAGIC %md
# MAGIC ## Step 2: Execute Cleansing & Data Quality Pipeline

# COMMAND ----------
from databricks.jobs.03_silver_cleansing_curation import process_silver_curation

silver_metrics = process_silver_curation(batch_id)
print("Silver Metrics Summary:", silver_metrics)

# COMMAND ----------
# MAGIC %md
# MAGIC ## Step 3: Master Patient Index & Gold Domain Transformation

# COMMAND ----------
from databricks.jobs.04_gold_domain_aggregation import run_gold_domain_modeling

gold_metrics = run_gold_domain_modeling(batch_id)
print("Gold Domain Modeling Summary:", gold_metrics)

# COMMAND ----------
# MAGIC %md
# MAGIC ## Step 4: High-Speed Idempotent Load into Azure PostgreSQL

# COMMAND ----------
from databricks.jobs.05_postgres_highspeed_loader import run_postgres_loader

load_metrics = run_postgres_loader(batch_id)
print("PostgreSQL Load Summary:", load_metrics)
print("Migration batch successfully completed!")
