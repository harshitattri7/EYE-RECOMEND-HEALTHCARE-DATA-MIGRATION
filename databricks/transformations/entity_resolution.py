"""
Master Patient Index (MPI) Entity Resolution & Deduplication Engine
Harmonizes patient identities across MariaDB EHR and Salesforce CRM.
"""
import uuid
import re
from typing import Dict, Any, List, Tuple, Optional
from difflib import SequenceMatcher

class MasterPatientIndexResolver:
    def __init__(self, confidence_threshold: float = 85.0):
        self.confidence_threshold = confidence_threshold
        self._mpi_registry: Dict[str, Dict[str, Any]] = {}

    @staticmethod
    def _clean_str(s: Optional[str]) -> str:
        if not s:
            return ""
        return re.sub(r"[^a-z0-9]", "", str(s).strip().lower())

    def _calculate_similarity(self, name_a: str, name_b: str) -> float:
        """Returns string similarity score between 0.0 and 100.0"""
        a = self._clean_str(name_a)
        b = self._clean_str(name_b)
        if not a or not b:
            return 0.0
        if a == b:
            return 100.0
        ratio = SequenceMatcher(None, a, b).ratio()
        return round(ratio * 100.0, 2)

    def resolve_patient_identity(
        self,
        source_system: str,
        source_record_id: str,
        mrn: Optional[str],
        first_name: str,
        last_name: str,
        dob: str,
        ssn_hash: Optional[str] = None
    ) -> Tuple[str, float, bool]:
        """
        Resolves identity against registered MPI records.
        Returns:
            (mpi_id, confidence_score, is_new_identity)
        """
        # Rule 1: Exact Deterministic Match on MRN
        if mrn:
            clean_mrn = self._clean_str(mrn)
            for mpi_id, record in self._mpi_registry.items():
                if record.get("mrn") and self._clean_str(record["mrn"]) == clean_mrn:
                    return mpi_id, 100.0, False

        # Rule 2: Deterministic Match on Hashed SSN + Exact DOB
        if ssn_hash and dob:
            for mpi_id, record in self._mpi_registry.items():
                if record.get("ssn_hash") == ssn_hash and record.get("dob") == dob:
                    return mpi_id, 99.5, False

        # Rule 3: Probabilistic Match on (Last Name == Match) AND (DOB == Match) AND (First Name Fuzzy >= 85)
        for mpi_id, record in self._mpi_registry.items():
            if record.get("dob") == dob and self._clean_str(record.get("last_name")) == self._clean_str(last_name):
                fn_score = self._calculate_similarity(record.get("first_name", ""), first_name)
                if fn_score >= self.confidence_threshold:
                    return mpi_id, fn_score, False

        # Rule 4: No match found -> Generate new Master Patient Index record
        new_mpi_id = str(uuid.uuid4())
        self._mpi_registry[new_mpi_id] = {
            "mpi_id": new_mpi_id,
            "enterprise_patient_id": f"EPI-{uuid.uuid4().hex[:8].upper()}",
            "mrn": mrn or f"MRN-AUTO-{new_mpi_id[:6].upper()}",
            "first_name": first_name,
            "last_name": last_name,
            "dob": dob,
            "ssn_hash": ssn_hash,
            "source_system": source_system,
            "source_record_id": source_record_id
        }
        return new_mpi_id, 100.0, True

    def get_registered_mpi_record(self, mpi_id: str) -> Optional[Dict[str, Any]]:
        return self._mpi_registry.get(mpi_id)
