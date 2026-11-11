"""
Unit Tests: Automated Reconciliation Engine
"""
import unittest
from scripts.reconciliation_engine import ReconciliationEngine

class TestReconciliation(unittest.TestCase):
    def setUp(self):
        self.engine = ReconciliationEngine(tolerance_pct=0.001)

    def test_exact_match_passes(self):
        res = self.engine.reconcile_table_pair(
            table_name="core.patients",
            source_system="MariaDB",
            source_count=100000,
            target_count=100000,
            source_checksum="HASH123",
            target_checksum="HASH123"
        )
        self.assertEqual(res["verdict"], "PASS")
        self.assertEqual(res["delta"], 0)
        self.assertEqual(res["variance_pct"], 0.0)

    def test_checksum_mismatch_fails(self):
        res = self.engine.reconcile_table_pair(
            table_name="clinical.encounters",
            source_system="MariaDB",
            source_count=50000,
            target_count=50000,
            source_checksum="HASH_AAA",
            target_checksum="HASH_BBB"
        )
        self.assertEqual(res["verdict"], "FAIL")
        self.assertFalse(res["checksum_match"])

    def test_tolerance_exceeded_fails(self):
        # 100 delta on 1000 records = 10% variance, which exceeds 0.001%
        res = self.engine.reconcile_table_pair(
            table_name="crm_billing_insurance.invoices",
            source_system="Salesforce",
            source_count=1000,
            target_count=1100
        )
        self.assertEqual(res["verdict"], "FAIL")

if __name__ == "__main__":
    unittest.main()
