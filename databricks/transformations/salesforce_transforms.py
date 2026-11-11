"""
Salesforce CRM Entity Transformations
Handles Salesforce 15-to-18 character ID normalization, field mapping, and CRM object ingestion.
"""
from datetime import datetime
from typing import Dict, Any, Optional

class SalesforceDataTransformer:
    @staticmethod
    def fix_salesforce_18_id(sf_id: Optional[str]) -> Optional[str]:
        """
        Converts 15-character case-sensitive Salesforce ID into 18-character case-insensitive ID
        using Salesforce checksum algorithm.
        """
        if not sf_id or len(sf_id) != 15:
            return sf_id

        lookup = "ABCDEFGHIJKLMNOPQRSTUVWXYZ012345"
        suffix = ""
        for i in range(3):
            flags = 0
            for j in range(5):
                c = sf_id[i * 5 + j]
                if "A" <= c <= "Z":
                    flags |= 1 << j
            suffix += lookup[flags]
        return sf_id + suffix

    def transform_sf_account(self, record: Dict[str, Any]) -> Dict[str, Any]:
        """Maps Salesforce Account sObject to crm_billing_insurance.sf_accounts"""
        raw_id = record.get("Id")
        sf_id = self.fix_salesforce_18_id(raw_id)
        
        return {
            "sf_account_id": sf_id,
            "account_name": record.get("Name", "Unknown Clinic"),
            "account_type": record.get("Type", "AFFILIATED_CLINIC"),
            "parent_account_id": self.fix_salesforce_18_id(record.get("ParentId")),
            "billing_street": record.get("BillingStreet"),
            "billing_city": record.get("BillingCity"),
            "billing_state": record.get("BillingState"),
            "billing_postal_code": record.get("BillingPostalCode"),
            "annual_revenue": float(record.get("AnnualRevenue", 0.0) or 0.0),
            "number_of_employees": int(record.get("NumberOfEmployees", 0) or 0),
            "sf_created_date": record.get("CreatedDate") or datetime.utcnow().isoformat() + "Z",
            "sf_last_modified_date": record.get("LastModifiedDate") or datetime.utcnow().isoformat() + "Z",
            "synced_at": datetime.utcnow().isoformat() + "Z"
        }

    def transform_sf_lead(self, record: Dict[str, Any]) -> Dict[str, Any]:
        """Maps Salesforce Lead sObject to crm_billing_insurance.sf_leads"""
        raw_id = record.get("Id")
        sf_id = self.fix_salesforce_18_id(raw_id)

        return {
            "sf_lead_id": sf_id,
            "first_name": record.get("FirstName"),
            "last_name": record.get("LastName", "Unknown"),
            "email": record.get("Email"),
            "phone": record.get("Phone"),
            "lead_source": record.get("LeadSource", "ONLINE_INQUIRY"),
            "lead_status": record.get("Status", "NEW"),
            "is_converted": bool(record.get("IsConverted", False)),
            "converted_patient_id": None,
            "sf_created_date": record.get("CreatedDate") or datetime.utcnow().isoformat() + "Z",
            "synced_at": datetime.utcnow().isoformat() + "Z"
        }
