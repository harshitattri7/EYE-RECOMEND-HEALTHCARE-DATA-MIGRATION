"""
Clinical Data Transformations for Legacy Drupal MariaDB EHR Records
Normalizes legacy entity models, timestamps, encounter statuses, and vitals.
"""
import uuid
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
from .pii_masking import HIPAAMasker

class ClinicalDataTransformer:
    def __init__(self, masker: Optional[HIPAAMasker] = None):
        self.masker = masker or HIPAAMasker()

    @staticmethod
    def epoch_to_iso(epoch_val: Any) -> Optional[str]:
        """Convert Unix epoch integer/string to ISO UTC format"""
        if epoch_val is None:
            return None
        try:
            ts = int(epoch_val)
            return datetime.fromtimestamp(ts, tz=timezone.utc).isoformat()
        except (ValueError, TypeError):
            if isinstance(epoch_val, str) and len(epoch_val) >= 10:
                return epoch_val
            return None

    @staticmethod
    def standardize_gender(gender_val: Optional[str]) -> str:
        """Harmonize legacy gender strings to standardized FHIR administrative gender"""
        if not gender_val:
            return "UNKNOWN"
        g = str(gender_val).strip().upper()
        if g in ["M", "MALE", "1"]:
            return "MALE"
        elif g in ["F", "FEMALE", "2"]:
            return "FEMALE"
        elif g in ["O", "OTHER", "NON_BINARY"]:
            return "OTHER"
        return "UNKNOWN"

    def transform_drupal_patient(self, row: Dict[str, Any], mpi_id: str) -> Dict[str, Any]:
        """Maps Drupal field_data_patient_demographics into target core.patients format"""
        deidentified = self.masker.deidentify_patient_record(row)
        
        patient_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"mrn:{row.get('field_mrn_value')}"))
        dob_val = row.get("field_dob_value")
        if isinstance(dob_val, str):
            dob = dob_val[:10]
        elif hasattr(dob_val, "strftime"):
            dob = dob_val.strftime("%Y-%m-%d")
        else:
            dob = "1980-01-01"

        return {
            "patient_id": patient_uuid,
            "mpi_id": mpi_id,
            "mrn": str(row.get("field_mrn_value")).strip().upper(),
            "first_name_masked": deidentified["first_name_masked"],
            "last_name_masked": deidentified["last_name_masked"],
            "date_of_birth": dob,
            "gender": self.standardize_gender(row.get("field_gender_value")),
            "ssn_last_four": deidentified["ssn_last_four"],
            "primary_language": "English",
            "is_deceased": False,
            "created_at": self.epoch_to_iso(row.get("created")) or datetime.utcnow().isoformat() + "Z",
            "updated_at": self.epoch_to_iso(row.get("changed")) or datetime.utcnow().isoformat() + "Z",
            "row_version": 1
        }

    def transform_drupal_encounter(self, row: Dict[str, Any], patient_id_map: Dict[int, str], practitioner_id: str, facility_id: str) -> Dict[str, Any]:
        """Maps Drupal node_clinical_encounter into clinical.encounters format"""
        nid = row.get("nid")
        encounter_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"encounter:nid:{nid}"))
        patient_nid = row.get("patient_nid")
        patient_id = patient_id_map.get(patient_nid, str(uuid.uuid4()))

        enc_date = row.get("encounter_date")
        if isinstance(enc_date, datetime):
            admission_ts = enc_date.isoformat()
        elif isinstance(enc_date, str):
            admission_ts = enc_date
        else:
            admission_ts = datetime.utcnow().isoformat() + "Z"

        raw_type = str(row.get("encounter_type", "COMPREHENSIVE_EYE_EXAM")).upper()
        
        return {
            "encounter_id": encounter_uuid,
            "patient_id": patient_id,
            "practitioner_id": practitioner_id,
            "facility_id": facility_id,
            "encounter_number": f"ENC-{nid}",
            "encounter_class": "AMBULATORY",
            "encounter_type": raw_type,
            "status": "COMPLETED",
            "admission_timestamp": admission_ts,
            "discharge_timestamp": None,
            "chief_complaint": row.get("chief_complaint", "Routine exam"),
            "service_delivery_location": "Main Clinic Optometry Suite 1",
            "created_at": self.epoch_to_iso(row.get("created")) or datetime.utcnow().isoformat() + "Z",
            "updated_at": self.epoch_to_iso(row.get("changed")) or datetime.utcnow().isoformat() + "Z",
            "row_version": 1
        }
