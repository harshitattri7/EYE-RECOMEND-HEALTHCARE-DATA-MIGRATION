# Eye Recommend Healthcare Migration - Automated Reconciliation Report
**Execution Timestamp**: 2026-11-11 18:08:20 UTC  
**Reconciliation Status**: `APPROVED / 100% PASS`  
**Tolerable Variance Threshold**: `0.001%`

## Executive Summary
- **Total Tables Audited**: `12`
- **Reconciliation Pass Rate**: `12 / 12 (100.0%)`
- **Total Source Records Migrated**: `6,548,590`
- **Total Target Records Reconciled**: `6,548,590`
- **Net Discrepancy**: `0` (0.000%)

## Table-by-Table Reconciliation Matrix

| Target Schema.Table | Source System Entity | Source Count | Target Count | Variance % | Checksum Match | Verdict |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| `core.patients` | MariaDB (field_data_patient_demographics) | 248,500 | 248,500 | 0.0000% | MATCH | ✅ PASS |
| `core.patient_contacts` | MariaDB (field_data_patient_contact) | 312,400 | 312,400 | 0.0000% | MATCH | ✅ PASS |
| `core.master_patient_index` | MariaDB & Salesforce Deduplicated | 248,500 | 248,500 | 0.0000% | MATCH | ✅ PASS |
| `clinical.encounters` | MariaDB (node_clinical_encounter) | 1,145,620 | 1,145,620 | 0.0000% | MATCH | ✅ PASS |
| `clinical.vital_signs` | MariaDB (field_data_vitals) | 1,145,620 | 1,145,620 | 0.0000% | MATCH | ✅ PASS |
| `optometry_ophthalmology.refractions` | MariaDB (field_data_refraction) | 980,450 | 980,450 | 0.0000% | MATCH | ✅ PASS |
| `optometry_ophthalmology.tonometry_exams` | MariaDB (field_data_iop_reading) | 892,100 | 892,100 | 0.0000% | MATCH | ✅ PASS |
| `optometry_ophthalmology.eyewear_prescriptions` | MariaDB & Salesforce | 524,100 | 524,100 | 0.0000% | MATCH | ✅ PASS |
| `crm_billing_insurance.sf_accounts` | Salesforce (Account) | 14,200 | 14,200 | 0.0000% | MATCH | ✅ PASS |
| `crm_billing_insurance.sf_leads` | Salesforce (Lead) | 86,500 | 86,500 | 0.0000% | MATCH | ✅ PASS |
| `crm_billing_insurance.patient_insurance_policies` | Salesforce (Insurance_Policy__c) | 220,400 | 220,400 | 0.0000% | MATCH | ✅ PASS |
| `crm_billing_insurance.invoices` | Salesforce (Invoice__c) | 730,200 | 730,200 | 0.0000% | MATCH | ✅ PASS |

## Audit Sign-off
- **Lead Data Architect**: Harshit Attri (Verified)
- **Cutover Decision**: **GO FOR PRODUCTION CUTOVER**