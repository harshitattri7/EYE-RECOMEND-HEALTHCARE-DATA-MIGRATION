# Source-to-Target Mapping (STTM) Specification
### Project: Eye Recommend Healthcare Data Migration

## 1. Overview
This specification details the extraction, harmonization, transformation, and load mapping logic for migrating legacy healthcare data from **Drupal MariaDB** and **Salesforce CRM** into the centralized **Azure PostgreSQL** database.

---

## 2. Domain Mapping Rules

### Domain 1: Patient Demographics & Identity (`core`)
| Target Schema | Target Table | Target Column | Source System | Source Table | Source Column | Transformation Rule |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `core` | `master_patient_index` | `mpi_id` | Both | Composite | `nid` / `Contact.Id` | Master Patient Index entity resolver (UUIDv4) |
| `core` | `master_patient_index` | `enterprise_patient_id` | Internal | Generated | - | `EPI-` + UUID8 uppercase prefix |
| `core` | `master_patient_index` | `primary_mrn` | MariaDB | `field_data_patient_demographics` | `field_mrn_value` | Standardized uppercase string |
| `core` | `patients` | `patient_id` | MariaDB | `node_patient_profile` | `nid` | Deterministic UUIDv5 from MRN |
| `core` | `patients` | `first_name_masked` | MariaDB | `field_data_patient_demographics` | `field_first_name_value` | First char + asterisks (e.g. `J***`) |
| `core` | `patients` | `last_name_masked` | MariaDB | `field_data_patient_demographics` | `field_last_name_value` | First char + asterisks (e.g. `D**`) |
| `core` | `patients` | `date_of_birth` | MariaDB | `field_data_patient_demographics` | `field_dob_value` | Cast to ISO DATE `YYYY-MM-DD` |
| `core` | `patients` | `gender` | MariaDB | `field_data_patient_demographics` | `field_gender_value` | Harmonized enum: `MALE`, `FEMALE`, `OTHER` |
| `core` | `patients` | `ssn_last_four` | MariaDB | `field_data_patient_demographics` | `field_ssn_value` | Regex `\\d{4}$` extraction |

### Domain 2: Clinical EHR Encounters (`clinical`)
| Target Schema | Target Table | Target Column | Source System | Source Table | Source Column | Transformation Rule |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `clinical` | `encounters` | `encounter_id` | MariaDB | `node_clinical_encounter` | `nid` | Deterministic UUIDv5 from encounter NID |
| `clinical` | `encounters` | `patient_id` | MariaDB | `node_clinical_encounter` | `patient_nid` | Foreign key reference to `core.patients` |
| `clinical` | `encounters` | `practitioner_id` | MariaDB | `node_clinical_encounter` | `provider_npi` | Foreign key lookup on `core.practitioners.npi` |
| `clinical` | `encounters` | `admission_timestamp` | MariaDB | `node_clinical_encounter` | `encounter_date` | Converted to UTC ISO 8601 string |
| `clinical` | `encounters` | `chief_complaint` | MariaDB | `node_clinical_encounter` | `chief_complaint` | Sanitized text; default 'Routine exam' |

### Domain 3: Ophthalmology & Optometry Exams (`optometry_ophthalmology`)
| Target Schema | Target Table | Target Column | Source System | Source Table | Source Column | Transformation Rule |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `optometry_ophthalmology` | `refractions` | `refraction_id` | MariaDB | `field_data_refraction` | `encounter_nid` | Deterministic UUIDv5 from encounter NID |
| `optometry_ophthalmology` | `refractions` | `od_sphere` | MariaDB | `field_data_refraction` | `od_sphere` | Round float to 2 decimal places (-25.00 to +25.00) |
| `optometry_ophthalmology` | `refractions` | `od_cylinder` | MariaDB | `field_data_refraction` | `od_cylinder` | Round float to 2 decimal places (minus cyl) |
| `optometry_ophthalmology` | `refractions` | `od_axis` | MariaDB | `field_data_refraction` | `od_axis` | Clamped integer between 1 and 180 |
| `optometry_ophthalmology` | `refractions` | `od_add` | MariaDB | `field_data_refraction` | `od_add` | Round float to 2 decimal places (+0.75 to +3.50) |
| `optometry_ophthalmology` | `tonometry_exams`| `iop_od_mmhg` | MariaDB | `field_data_refraction` | `iop_od` | Round float to 1 decimal place (3.0 to 70.0) |

### Domain 4: Salesforce CRM & Insurance Billing (`crm_billing_insurance`)
| Target Schema | Target Table | Target Column | Source System | Source Table | Source Column | Transformation Rule |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `crm_billing_insurance` | `sf_accounts` | `sf_account_id` | Salesforce | `Account` | `Id` | Convert 15-char ID to 18-char case-insensitive ID |
| `crm_billing_insurance` | `sf_accounts` | `account_name` | Salesforce | `Account` | `Name` | Standardized title case string |
| `crm_billing_insurance` | `sf_leads` | `sf_lead_id` | Salesforce | `Lead` | `Id` | Convert 15-char ID to 18-char case-insensitive ID |
| `crm_billing_insurance` | `patient_insurance_policies` | `policy_id` | Salesforce | `Insurance_Policy__c` | `Id` | UUIDv5 from Salesforce Policy Id |
| `crm_billing_insurance` | `invoices` | `total_gross_amount` | Salesforce | `Invoice__c` | `Total_Amount__c` | Currency numeric(10,2) rounding |
