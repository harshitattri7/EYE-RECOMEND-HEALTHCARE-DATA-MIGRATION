"""
Unit Tests: Automated Data Quality Engine
"""
import unittest
from databricks.framework.data_quality import DataQualityEngine, DataQualityRule

class TestDataQuality(unittest.TestCase):
    def setUp(self):
        self.engine = DataQualityEngine(target_schema="optometry_ophthalmology", target_table="refractions")

    def test_clean_records_pass(self):
        valid_records = [
            {
                "patient_id": "P-100",
                "od_sphere": -2.50,
                "os_sphere": -2.75,
                "od_axis": 90,
                "os_axis": 85
            }
        ]
        clean, quarantined = self.engine.validate_records(valid_records)
        self.assertEqual(len(clean), 1)
        self.assertEqual(len(quarantined), 0)

    def test_out_of_range_refraction_quarantined(self):
        invalid_records = [
            {
                "patient_id": "P-BAD-SPHERE",
                "od_sphere": -99.00, # Impossibly high diopter (normal range -25 to +25)
                "os_sphere": -2.50,
                "od_axis": 90,
                "os_axis": 90
            }
        ]
        clean, quarantined = self.engine.validate_records(invalid_records)
        self.assertEqual(len(clean), 0)
        self.assertEqual(len(quarantined), 1)
        self.assertIn("RANGE_OD_SPHERE", quarantined[0]["failed_rules"])

    def test_null_validation(self):
        patient_engine = DataQualityEngine(target_schema="core", target_table="patients")
        records = [
            {"patient_id": "P-1", "mrn": None, "date_of_birth": "1990-05-15", "last_name_masked": "Smith"},
            {"patient_id": "P-2", "mrn": "MRN-VALID", "date_of_birth": "1990-05-15", "last_name_masked": "Jones"}
        ]
        clean, quarantined = patient_engine.validate_records(records)
        self.assertEqual(len(clean), 1)
        self.assertEqual(len(quarantined), 1)
        self.assertEqual(quarantined[0]["source_record_key"], "P-1")

if __name__ == "__main__":
    unittest.main()
