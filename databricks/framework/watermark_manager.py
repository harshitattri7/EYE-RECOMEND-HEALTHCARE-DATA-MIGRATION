"""
High-Watermark Incremental State Manager
Tracks last successful extract timestamps and offsets to guarantee idempotency and zero data loss.
"""
import os
from datetime import datetime, timezone
from typing import Optional, Dict, Any
from .logger import MigrationLogger

logger = MigrationLogger("WatermarkManager")

class WatermarkManager:
    def __init__(self, db_connection=None):
        self.conn = db_connection
        self._local_cache: Dict[str, datetime] = {}

    def get_watermark(self, target_schema: str, target_table: str) -> datetime:
        """
        Retrieves the last processed watermark timestamp for a table.
        Defaults to Unix Epoch (1970-01-01) if table is migrating for the first time.
        """
        table_key = f"{target_schema}.{target_table}"
        
        if self.conn:
            try:
                cursor = self.conn.cursor()
                query = """
                    SELECT w.last_processed_watermark_timestamp
                    FROM metadata_ops.watermark_registry w
                    JOIN metadata_ops.table_manifest_catalog m ON w.table_id = m.table_id
                    WHERE m.target_schema = %s AND m.target_table_name = %s
                    LIMIT 1;
                """
                cursor.execute(query, (target_schema, target_table))
                row = cursor.fetchone()
                cursor.close()
                if row and row[0]:
                    return row[0]
            except Exception as e:
                logger.warning(f"Could not read DB watermark for {table_key}, using fallback", error=str(e))

        # Cached or default epoch fallback
        return self._local_cache.get(table_key, datetime(1970, 1, 1, 0, 0, 0, tzinfo=timezone.utc))

    def update_watermark(self, target_schema: str, target_table: str, new_watermark: datetime, batch_id: Optional[str] = None):
        """
        Atomically updates the watermark timestamp in metadata_ops.watermark_registry.
        """
        table_key = f"{target_schema}.{target_table}"
        self._local_cache[table_key] = new_watermark

        if self.conn:
            try:
                cursor = self.conn.cursor()
                query = """
                    INSERT INTO metadata_ops.watermark_registry (table_id, last_processed_watermark_timestamp, last_sync_batch_id, updated_at)
                    SELECT table_id, %s, %s::uuid, CURRENT_TIMESTAMP
                    FROM metadata_ops.table_manifest_catalog
                    WHERE target_schema = %s AND target_table_name = %s
                    ON CONFLICT (watermark_id) DO UPDATE
                    SET last_processed_watermark_timestamp = EXCLUDED.last_processed_watermark_timestamp,
                        last_sync_batch_id = EXCLUDED.last_sync_batch_id,
                        updated_at = CURRENT_TIMESTAMP;
                """
                cursor.execute(query, (new_watermark, batch_id, target_schema, target_table))
                self.conn.commit()
                cursor.close()
                logger.info(f"Updated watermark for {table_key} to {new_watermark.isoformat()}")
            except Exception as e:
                logger.error(f"Failed to persist watermark update to database for {table_key}", exc=e)
        else:
            logger.info(f"Updated in-memory watermark for {table_key} to {new_watermark.isoformat()}")
