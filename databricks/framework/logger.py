"""
Migration Structured Logger with Azure Monitor / Log Analytics compatibility.
"""
import os
import sys
import json
import logging
from datetime import datetime, timezone
from typing import Optional, Dict, Any

class MigrationLogger:
    def __init__(self, component_name: str, batch_id: Optional[str] = None):
        self.component_name = component_name
        self.batch_id = batch_id or "BATCH-LOCAL-001"
        self._logger = logging.getLogger(f"EyeRecommend.{component_name}")
        self._logger.setLevel(logging.INFO)

        if not self._logger.handlers:
            handler = logging.StreamHandler(sys.stdout)
            formatter = logging.Formatter(
                fmt="%(asctime)s [%(levelname)s] [%(name)s] %(message)s",
                datefmt="%Y-%m-%d %H:%M:%S"
            )
            handler.setFormatter(formatter)
            self._logger.addHandler(handler)

    def _format_event(self, level: str, message: str, context: Optional[Dict[str, Any]] = None) -> str:
        payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "batch_id": self.batch_id,
            "component": self.component_name,
            "level": level,
            "message": message,
            "context": context or {}
        }
        return json.dumps(payload)

    def info(self, message: str, **kwargs):
        formatted = self._format_event("INFO", message, kwargs)
        self._logger.info(formatted)

    def warning(self, message: str, **kwargs):
        formatted = self._format_event("WARN", message, kwargs)
        self._logger.warning(formatted)

    def error(self, message: str, exc: Optional[Exception] = None, **kwargs):
        ctx = kwargs.copy()
        if exc:
            ctx["exception_type"] = type(exc).__name__
            ctx["exception_msg"] = str(exc)
        formatted = self._format_event("ERROR", message, ctx)
        self._logger.error(formatted)

    def audit(self, action: str, record_count: int, table_name: str, **kwargs):
        ctx = {
            "audit_action": action,
            "record_count": record_count,
            "table_name": table_name,
            **kwargs
        }
        formatted = self._format_event("AUDIT", f"Audited {action} on {table_name}", ctx)
        self._logger.info(formatted)
