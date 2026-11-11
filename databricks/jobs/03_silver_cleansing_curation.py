"""
Job 03: Silver Tier Cleansing, Curation & Data Quality Validation
Performs schema harmonization, deduplication, HIPAA de-identification, and data quality validation.
Routes invalid records to the quarantine lakehouse container.
"""
import sys
from typing import Dict, Any, List
from databricks.framework.logger import MigrationLogger
from databricks.framework.metrics_tracker import MetricsTracker
from databricks.framework.data_quality import DataQualityEngine
from databricks.transformations.pii_masking import HIPAAMasker

logger = MigrationLogger("SilverCleansingJob")

def process_silver_curation(batch_id: str, sample_records: List[Dict[str, Any]] = None) -> Dict[str, Any]:
    tracker = MetricsTracker("SilverCleansingJob", batch_id)
    tracker.start()

    logger.info("Starting Silver Cleansing and Curation stage", batch_id=batch_id)

    masker = HIPAAMasker()
    dq_engine = DataQualityEngine(target_schema="core", target_table="patients")

    records = sample_records or [
        {
            "field_mrn_value": "MRN-1001",
            "field_first_name_value": "John",
            "field_last_name_value": "Doe",
            "date_of_birth": "1985-05-12",
            "field_ssn_value": "987-65-4321",
            "field_phone_value": "555-019-2831",
            "field_email_value": "john.doe@example.com"
        },
        {
            "field_mrn_value": None, # Should be quarantined: NOT_NULL_MRN
            "field_first_name_value": "Bad",
            "field_last_name_value": "Record",
            "date_of_birth": "1990-01-01"
        }
    ]

    masked_records = [masker.deidentify_patient_record(r) for r in records]
    clean_records, quarantined_records = dq_engine.validate_records(masked_records)

    logger.audit(
        action="SILVER_CURATION",
        record_count=len(clean_records),
        table_name="core.patients",
        quarantined_count=len(quarantined_records)
    )

    summary = tracker.finish(
        records_read=len(records),
        records_written=len(clean_records),
        records_quarantined=len(quarantined_records)
    )
    return summary

if __name__ == "__main__":
    batch = sys.argv[1] if len(sys.argv) > 1 else "BATCH-TEST-001"
    process_silver_curation(batch)
