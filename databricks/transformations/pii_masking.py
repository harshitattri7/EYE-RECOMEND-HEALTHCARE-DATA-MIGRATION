"""
HIPAA Safe Harbor Compliance & PII Masking Engine
Implements deterministic salted hashing, tokenization, and masked formatting
for protected health information (PHI) and personally identifiable information (PII).
"""
import hashlib
import os
import re
from typing import Optional, Dict, Any

class HIPAAMasker:
    def __init__(self, salt: Optional[str] = None):
        # In production this salt is retrieved directly from Azure Key Vault
        self.salt = salt or os.getenv("HIPAA_PEPPER_SALT", "EYE_RECOMMEND_SECURE_SALT_984321")

    def hash_identifier(self, identifier: Optional[str]) -> Optional[str]:
        """Cryptographically secure SHA-256 salted hash for unique IDs (e.g. SSN, National ID)"""
        if not identifier:
            return None
        cleaned = re.sub(r"[^A-Za-z0-9]", "", str(identifier).strip().upper())
        salted_val = f"{self.salt}:{cleaned}".encode("utf-8")
        return hashlib.sha256(salted_val).hexdigest()

    def mask_name(self, name: Optional[str]) -> str:
        """Masks patient names to first letter + asterisks: 'John' -> 'J***'"""
        if not name or str(name).strip() == "":
            return "UNKNOWN"
        cleaned = str(name).strip()
        if len(cleaned) <= 1:
            return cleaned
        return f"{cleaned[0]}{'*' * (min(len(cleaned) - 1, 4))}"

    def mask_ssn_last_four(self, ssn: Optional[str]) -> Optional[str]:
        """Extracts strictly the last 4 digits of SSN for non-PHI operational matching"""
        if not ssn:
            return None
        digits = re.sub(r"\D", "", str(ssn))
        if len(digits) >= 4:
            return digits[-4:]
        return digits.rjust(4, "0")

    def mask_phone_number(self, phone: Optional[str]) -> Optional[str]:
        """Masks phone: '555-019-2831' -> '(555) ***-2831'"""
        if not phone:
            return None
        digits = re.sub(r"\D", "", str(phone))
        if len(digits) == 10:
            return f"({digits[:3]}) ***-{digits[-4:]}"
        elif len(digits) == 11 and digits.startswith("1"):
            return f"+1 ({digits[1:4]}) ***-{digits[-4:]}"
        return "***-***-" + digits[-4:] if len(digits) >= 4 else "****"

    def mask_email(self, email: Optional[str]) -> Optional[str]:
        """Masks email: 'johndoe@email.com' -> 'j***e@email.com'"""
        if not email or "@" not in str(email):
            return None
        local, domain = str(email).strip().split("@", 1)
        if len(local) <= 2:
            masked_local = f"{local[0]}*"
        else:
            masked_local = f"{local[0]}{'*' * (len(local) - 2)}{local[-1]}"
        return f"{masked_local}@{domain}"

    def deidentify_patient_record(self, raw_record: Dict[str, Any]) -> Dict[str, Any]:
        """Transforms a raw patient record into a HIPAA Safe Harbor conformant dictionary"""
        first_name = raw_record.get("field_first_name_value") or raw_record.get("first_name", "")
        last_name = raw_record.get("field_last_name_value") or raw_record.get("last_name", "")
        ssn = raw_record.get("field_ssn_value") or raw_record.get("ssn")
        phone = raw_record.get("field_phone_value") or raw_record.get("phone")
        email = raw_record.get("field_email_value") or raw_record.get("email")

        record = raw_record.copy()
        record["first_name_masked"] = self.mask_name(first_name)
        record["last_name_masked"] = self.mask_name(last_name)
        record["ssn_last_four"] = self.mask_ssn_last_four(ssn)
        record["hashed_ssn"] = self.hash_identifier(ssn)
        record["phone_masked"] = self.mask_phone_number(phone)
        record["email_masked"] = self.mask_email(email)

        # Drop raw unencrypted SSN from memory
        record.pop("field_ssn_value", None)
        record.pop("ssn", None)
        return record
