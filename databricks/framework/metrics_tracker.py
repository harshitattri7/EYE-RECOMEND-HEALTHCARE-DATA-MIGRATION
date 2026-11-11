"""
Pipeline Metrics Tracker and Performance Telemetry
Captures records processed, elapsed time, throughput (records/sec), and memory usage.
"""
import time
import os
from typing import Dict, Any, Optional
from datetime import datetime
from .logger import MigrationLogger

class MetricsTracker:
    def __init__(self, step_name: str, batch_id: str):
        self.step_name = step_name
        self.batch_id = batch_id
        self.start_time: float = 0.0
        self.end_time: float = 0.0
        self.records_read: int = 0
        self.records_written: int = 0
        self.records_quarantined: int = 0
        self.custom_metrics: Dict[str, Any] = {}
        self.logger = MigrationLogger(f"Metrics.{step_name}", batch_id=batch_id)

    def start(self):
        self.start_time = time.perf_counter()
        self.logger.info(f"Started pipeline step: {self.step_name}")

    def finish(self, records_read: int = 0, records_written: int = 0, records_quarantined: int = 0) -> Dict[str, Any]:
        self.end_time = time.perf_counter()
        self.records_read = records_read
        self.records_written = records_written
        self.records_quarantined = records_quarantined
        
        duration_sec = max(self.end_time - self.start_time, 0.001)
        throughput = round(self.records_written / duration_sec, 2)

        summary = {
            "step_name": self.step_name,
            "batch_id": self.batch_id,
            "duration_seconds": round(duration_sec, 3),
            "records_read": self.records_read,
            "records_written": self.records_written,
            "records_quarantined": self.records_quarantined,
            "throughput_records_per_sec": throughput,
            "completed_at": datetime.utcnow().isoformat() + "Z",
            **self.custom_metrics
        }

        self.logger.info(
            f"Completed pipeline step: {self.step_name}",
            duration_sec=round(duration_sec, 2),
            records_written=records_written,
            throughput=throughput
        )
        return summary
