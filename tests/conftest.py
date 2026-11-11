"""
Shared Pytest Fixtures
"""
import os
import sys

try:
    import pytest
except ImportError:
    pytest = None

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

def sample_patient_raw_data():
    return {
        "field_mrn_value": "MRN-EYE-10001",
        "field_first_name_value": "John",
        "field_last_name_value": "Doe",
        "field_dob_value": "1982-04-12",
        "field_gender_value": "MALE",
        "field_ssn_value": "987-65-4321",
        "field_phone_value": "555-019-2831",
        "field_email_value": "johndoe@email.com",
        "created": 1609459200,
        "changed": 1672531199
    }

if pytest is not None:
    @pytest.fixture
    def sample_patient_raw():
        return sample_patient_raw_data()


@pytest.fixture
def sample_refraction_raw():
    return {
        "encounter_nid": 5001,
        "patient_nid": 1001,
        "od_sphere": -2.50,
        "od_cylinder": -0.75,
        "od_axis": 95,
        "od_add": 1.75,
        "os_sphere": -2.75,
        "os_cylinder": -0.50,
        "os_axis": 85,
        "os_add": 1.75,
        "pd_binocular": 63.5,
        "iop_od": 14.5,
        "iop_os": 15.0
    }
