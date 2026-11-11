"""
Unit Tests: Master Patient Index (MPI) Entity Resolution
"""
import unittest
from databricks.transformations.entity_resolution import MasterPatientIndexResolver

class TestEntityResolution(unittest.TestCase):
    def setUp(self):
        self.resolver = MasterPatientIndexResolver(confidence_threshold=85.0)

    def test_deterministic_mrn_match(self):
        # Register initial patient
        mpi_1, score_1, is_new_1 = self.resolver.resolve_patient_identity(
            source_system="DRUPAL_MARIADB",
            source_record_id="101",
            mrn="MRN-TEST-101",
            first_name="Jane",
            last_name="Doe",
            dob="1990-01-01"
        )
        self.assertTrue(is_new_1)

        # Encounter from Salesforce with same MRN
        mpi_2, score_2, is_new_2 = self.resolver.resolve_patient_identity(
            source_system="SALESFORCE_CRM",
            source_record_id="003A000000123XYZ",
            mrn="MRN-TEST-101",
            first_name="Jane",
            last_name="Doe",
            dob="1990-01-01"
        )
        self.assertFalse(is_new_2)
        self.assertEqual(mpi_1, mpi_2)
        self.assertEqual(score_2, 100.0)

    def test_probabilistic_fuzzy_name_match(self):
        # Register patient with full name "Jonathan"
        mpi_1, _, is_new_1 = self.resolver.resolve_patient_identity(
            source_system="DRUPAL_MARIADB",
            source_record_id="202",
            mrn="MRN-TEST-202",
            first_name="Jonathan",
            last_name="Williams",
            dob="1985-06-20"
        )
        self.assertTrue(is_new_1)

        # Salesforce lead with nickname "Jon" and no MRN
        mpi_2, score_2, is_new_2 = self.resolver.resolve_patient_identity(
            source_system="SALESFORCE_CRM",
            source_record_id="00Q3A000000999ABC",
            mrn=None,
            first_name="Jonathon", # Slight typo
            last_name="Williams",
            dob="1985-06-20"
        )
        self.assertFalse(is_new_2)
        self.assertEqual(mpi_1, mpi_2)
        self.assertGreaterEqual(score_2, 85.0)

if __name__ == "__main__":
    unittest.main()
