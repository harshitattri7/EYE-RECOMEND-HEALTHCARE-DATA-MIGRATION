"""
Automated Data Quality & Validation Engine
Applies healthcare-specific DQ rules, schema validation, and routes defective records to quarantine.
"""
import re
from typing import List, Dict, Any, Tuple, Optional
from datetime import datetime, timezone
from .logger import MigrationLogger

logger = MigrationLogger("DataQualityEngine")

class DataQualityRule:
    def __init__(self, rule_name: str, column_name: str, rule_type: str, severity: str = "BLOCKING", params: Optional[Dict[str, Any]] = None):
        self.rule_name = rule_name
        self.column_name = column_name
        self.rule_type = rule_type # 'NOT_NULL', 'REGEX_MATCH', 'VALUE_RANGE', 'LOOKUP_EXISTS', 'DATE_LOGIC'
        self.severity = severity # 'BLOCKING', 'WARNING'
        self.params = params or {}

class DataQualityEngine:
    def __init__(self, target_schema: str, target_table: str):
        self.target_schema = target_schema
        self.target_table = target_table
        self.rules: List[DataQualityRule] = []
        self._load_default_rules()

    def add_rule(self, rule: DataQualityRule):
        self.rules.append(rule)

    def _load_default_rules(self):
        """Standard healthcare data hygiene rules based on target table"""
        if self.target_table == "patients":
            self.rules.extend([
                DataQualityRule("NOT_NULL_MRN", "mrn", "NOT_NULL", "BLOCKING"),
                DataQualityRule("VALID_DOB_RANGE", "date_of_birth", "DATE_RANGE", "BLOCKING", {"min_year": 1890, "max_year": datetime.now(timezone.utc).year}),
                DataQualityRule("NOT_NULL_LAST_NAME", "last_name_masked", "NOT_NULL", "BLOCKING")
            ])
        elif self.target_table == "refractions":
            self.rules.extend([
                DataQualityRule("RANGE_OD_SPHERE", "od_sphere", "VALUE_RANGE", "BLOCKING", {"min_val": -25.00, "max_val": +25.00}),
                DataQualityRule("RANGE_OS_SPHERE", "os_sphere", "VALUE_RANGE", "BLOCKING", {"min_val": -25.00, "max_val": +25.00}),
                DataQualityRule("RANGE_OD_AXIS", "od_axis", "VALUE_RANGE", "WARNING", {"min_val": 1, "max_val": 180}),
                DataQualityRule("RANGE_OS_AXIS", "os_axis", "VALUE_RANGE", "WARNING", {"min_val": 1, "max_val": 180})
            ])
        elif self.target_table == "tonometry_exams":
            self.rules.extend([
                DataQualityRule("RANGE_IOP_OD", "iop_od_mmhg", "VALUE_RANGE", "BLOCKING", {"min_val": 3.0, "max_val": 70.0}),
                DataQualityRule("RANGE_IOP_OS", "iop_os_mmhg", "VALUE_RANGE", "BLOCKING", {"min_val": 3.0, "max_val": 70.0})
            ])

    def validate_records(self, records: List[Dict[str, Any]]) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
        """
        Validates an in-memory batch of dictionary records.
        Returns:
            clean_records: List of valid records
            quarantine_records: List of rejected records enriched with failed rule and reason
        """
        clean_records = []
        quarantine_records = []

        for record in records:
            failed_rules = []
            reasons = []

            for rule in self.rules:
                val = record.get(rule.column_name)

                if rule.rule_type == "NOT_NULL":
                    if val is None or str(val).strip() == "" or str(val).lower() == "none":
                        failed_rules.append(rule.rule_name)
                        reasons.append(f"Field '{rule.column_name}' must not be null or blank")

                elif rule.rule_type == "VALUE_RANGE":
                    if val is not None:
                        try:
                            num = float(val)
                            min_val = rule.params.get("min_val", -float("inf"))
                            max_val = rule.params.get("max_val", float("inf"))
                            if num < min_val or num > max_val:
                                failed_rules.append(rule.rule_name)
                                reasons.append(f"Field '{rule.column_name}' value {num} is outside valid clinical range [{min_val}, {max_val}]")
                        except (ValueError, TypeError):
                            failed_rules.append(rule.rule_name)
                            reasons.append(f"Field '{rule.column_name}' cannot be cast to numeric value: {val}")

                elif rule.rule_type == "DATE_RANGE":
                    if val is not None:
                        try:
                            if isinstance(val, str):
                                dt = datetime.strptime(val[:10], "%Y-%m-%d")
                            elif hasattr(val, "year"):
                                dt = val
                            else:
                                dt = datetime.utcnow()
                            min_year = rule.params.get("min_year", 1900)
                            max_year = rule.params.get("max_year", datetime.now(timezone.utc).year)
                            if dt.year < min_year or dt.year > max_year:
                                failed_rules.append(rule.rule_name)
                                reasons.append(f"Date '{rule.column_name}' year {dt.year} is outside range [{min_year}, {max_year}]")
                        except Exception as e:
                            failed_rules.append(rule.rule_name)
                            reasons.append(f"Invalid date format in '{rule.column_name}': {str(e)}")

            if failed_rules:
                quarantine_entry = {
                    "raw_record": record,
                    "target_schema": self.target_schema,
                    "target_table": self.target_table,
                    "source_record_key": str(record.get("patient_id") or record.get("mrn") or record.get("nid") or "UNKNOWN"),
                    "failed_rules": failed_rules,
                    "rejection_reasons": reasons,
                    "quarantined_at": datetime.now(timezone.utc).isoformat()
                }
                quarantine_records.append(quarantine_entry)
            else:
                clean_records.append(record)

        logger.info(
            f"Data Quality Validation: {self.target_schema}.{self.target_table}",
            total_records=len(records),
            clean_records=len(clean_records),
            quarantined_records=len(quarantine_records)
        )
        return clean_records, quarantine_records
