"""
Unit Tests: Data Transformations & Masking
"""
import unittest
from databricks.transformations.pii_masking import HIPAAMasker
from databricks.transformations.clinical_transforms import ClinicalDataTransformer
from databricks.transformations.salesforce_transforms import SalesforceDataTransformer
from databricks.transformations.ophthalmology_transforms import OphthalmologyDataTransformer

class TestTransformations(unittest.TestCase):
    def setUp(self):
        self.masker = HIPAAMasker(salt="TEST_SALT_XYZ_123")
        self.clinical = ClinicalDataTransformer(self.masker)
        self.salesforce = SalesforceDataTransformer()
        self.optom = OphthalmologyDataTransformer()

    def test_hipaa_ssn_masking(self):
        raw_ssn = "987-65-4321"
        last_four = self.masker.mask_ssn_last_four(raw_ssn)
        hashed_ssn = self.masker.hash_identifier(raw_ssn)

        self.assertEqual(last_four, "4321")
        self.assertIsNotNone(hashed_ssn)
        self.assertEqual(len(hashed_ssn), 64) # SHA-256 hex string

    def test_hipaa_name_masking(self):
        self.assertEqual(self.masker.mask_name("Alexander"), "A****")
        self.assertEqual(self.masker.mask_name(""), "UNKNOWN")

    def test_hipaa_phone_and_email_masking(self):
        phone_masked = self.masker.mask_phone_number("5550192831")
        self.assertEqual(phone_masked, "(555) ***-2831")

        email_masked = self.masker.mask_email("johndoe@eyerecommend.com")
        self.assertTrue(email_masked.startswith("j"))
        self.assertTrue(email_masked.endswith("@eyerecommend.com"))

    def test_gender_standardization(self):
        self.assertEqual(self.clinical.standardize_gender("m"), "MALE")
        self.assertEqual(self.clinical.standardize_gender("Female"), "FEMALE")
        self.assertEqual(self.clinical.standardize_gender(None), "UNKNOWN")

    def test_salesforce_18_char_id_conversion(self):
        # Test standard 15-to-18 char conversion
        sf_15 = "001300000000AAA"
        sf_18 = self.salesforce.fix_salesforce_18_id(sf_15)
        self.assertEqual(len(sf_18), 18)
        self.assertTrue(sf_18.startswith(sf_15))

    def test_optometry_refraction_clamping(self):
        self.assertEqual(self.optom.clamp_axis(0), 1)
        self.assertEqual(self.optom.clamp_axis(195), 180)
        self.assertEqual(self.optom.clamp_axis(95), 95)
        self.assertEqual(self.optom.parse_diopter("-2.50"), -2.50)

if __name__ == "__main__":
    unittest.main()
