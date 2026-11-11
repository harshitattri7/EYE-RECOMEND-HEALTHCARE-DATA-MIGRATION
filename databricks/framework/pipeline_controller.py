"""
Metadata-Driven Batch Pipeline Controller
Coordinates the execution of large-scale migration phases across 300+ production tables.
"""
import uuid
from datetime import datetime
from typing import List, Dict, Any, Optional
from .logger import MigrationLogger
from .metrics_tracker import MetricsTracker

class PipelineController:
    def __init__(self, batch_name: str, migration_phase: str = "PRODUCTION_CUTOVER", db_connection=None):
        self.batch_id = str(uuid.uuid4())
        self.batch_name = batch_name
        self.migration_phase = migration_phase
        self.conn = db_connection
        self.logger = MigrationLogger("PipelineController", batch_id=self.batch_id)
        self.tables_processed = 0
        self.records_ingested = 0
        self.records_inserted = 0
        self.records_updated = 0
        self.records_quarantined = 0

    def start_batch(self):
        """Register the batch execution in metadata_ops.batch_control_ledger"""
        self.logger.info(
            f"Starting Migration Batch: {self.batch_name}",
            batch_id=self.batch_id,
            phase=self.migration_phase
        )

        if self.conn:
            try:
                cursor = self.conn.cursor()
                query = """
                    INSERT INTO metadata_ops.batch_control_ledger
                    (batch_id, batch_name, migration_phase, source_system, execution_status, start_timestamp, triggered_by)
                    VALUES (%s, %s, %s, 'ALL', 'RUNNING', CURRENT_TIMESTAMP, 'DATABRICKS_CONTROLLER');
                """
                cursor.execute(query, (self.batch_id, self.batch_name, self.migration_phase))
                self.conn.commit()
                cursor.close()
            except Exception as e:
                self.logger.error("Failed to register batch in ledger", exc=e)

    def record_step_metrics(self, step_summary: Dict[str, Any]):
        """Accumulate metrics from executed jobs"""
        self.tables_processed += 1
        self.records_ingested += step_summary.get("records_read", 0)
        self.records_inserted += step_summary.get("records_written", 0)
        self.records_quarantined += step_summary.get("records_quarantined", 0)

    def complete_batch(self, status: str = "COMPLETED") -> Dict[str, Any]:
        """Finalize the batch in metadata_ops.batch_control_ledger"""
        summary = {
            "batch_id": self.batch_id,
            "batch_name": self.batch_name,
            "status": status,
            "total_tables_processed": self.tables_processed,
            "total_records_ingested": self.records_ingested,
            "total_records_inserted": self.records_inserted,
            "total_records_quarantined": self.records_quarantined,
            "completed_at": datetime.utcnow().isoformat() + "Z"
        }

        self.logger.info("Batch execution finished", **summary)

        if self.conn:
            try:
                cursor = self.conn.cursor()
                query = """
                    UPDATE metadata_ops.batch_control_ledger
                    SET execution_status = %s,
                        end_timestamp = CURRENT_TIMESTAMP,
                        total_tables_processed = %s,
                        total_records_ingested = %s,
                        total_records_inserted = %s,
                        total_records_quarantined = %s
                    WHERE batch_id = %s;
                """
                cursor.execute(
                    query,
                    (
                        status,
                        self.tables_processed,
                        self.records_ingested,
                        self.records_inserted,
                        self.records_quarantined,
                        self.batch_id
                    )
                )
                self.conn.commit()
                cursor.close()
            except Exception as e:
                self.logger.error("Failed to finalize batch in ledger", exc=e)

        return summary
