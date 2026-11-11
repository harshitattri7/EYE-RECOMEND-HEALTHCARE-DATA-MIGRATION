# Data Dictionary & Schema Architecture: 300+ Production Tables
### Project: Eye Recommend Healthcare Data Migration
**Database Engine:** Azure Database for PostgreSQL Flexible Server 15

---

## 1. Schema Domain Distribution Summary

| Schema Name | Production Tables | Functional Domain | Primary Data Sources |
| :--- | :---: | :--- | :--- |
| `core` | **45** | Master Patient Index (MPI), Demographics, Addresses, Consents, Practitioners | Drupal MariaDB & Salesforce |
| `clinical` | **55** | EHR Encounters, SOAP Notes, Vital Signs, Lab Tests, Care Plans | Drupal MariaDB Clinical EHR |
| `diagnostics_procedures` | **40** | ICD-10 Catalogs, SNOMED Concepts, CPT Codes, Surgical Logs, Biopsies | Drupal MariaDB Clinical EHR |
| `pharmacy_medications` | **35** | NDC Catalog, Prescriptions, Dispenary Logs, Drug Interactions | Drupal MariaDB Clinical EHR |
| `optometry_ophthalmology` | **45** | Refraction OD/OS, Tonometry IOP, Visual Acuity, Eyewear Orders, Optical Labs | Drupal MariaDB EHR |
| `crm_billing_insurance` | **50** | Salesforce CRM Accounts, Leads, Policies, Invoices, Claims EDI 837 | Salesforce CRM & Claims |
| `metadata_ops` | **30** | Migration Batch Ledger, Watermarks, Data Quality Quarantine, Reconciliations | Azure ADF & Databricks |
| **Total Ecosystem** | **300+** | **Enterprise Healthcare Lakehouse & Application Database** | **All Integrated Systems** |

---

## 2. Exhaustive Schema Descriptions

### 2.1 Schema: `core` (45 Tables)
- `master_patient_index`: Golden record enterprise patient identity and confidence score.
- `patient_source_cross_reference`: Source system mappings (MariaDB NID, Salesforce Contact Id).
- `patients`: Demographics, encrypted name tokens, masked names, birth date, gender, SSN last 4.
- `patient_contacts`: Phone numbers, email addresses, SMS preferences.
- `patient_addresses`: Residential, mailing, billing addresses with geocodes.
- `patient_emergency_contacts`: Primary and secondary next of kin.
- `patient_guardians`: Legal guardians, powers of attorney, healthcare proxies.
- `patient_consents`: HIPAA compliance privacy agreements and signatures.
- `patient_government_identifiers`: Driver licenses, state IDs with SHA-256 tokens.
- `patient_portal_accounts`: Online patient portal logins and MFA state.
- `patient_preferences`: Preferred clinics, language, provider preferences.
- `patient_relationships`: Family relationships and guarantor linkages.
- `patient_employer_history`: Historical and current employer records.
- `patient_merge_history`: Audit record of deduplicated/merged patient identities.
- `patient_flags`: Fall risk, infection control, high-priority flags.
- `patient_allergies_registry`: Drug, food, environmental allergens.
- `patient_immunization_registry`: Vaccines, lot numbers, manufacturers.
- `patient_care_team_members`: Primary optometrist, ophthalmologist, PCP linkages.
- `patient_family_medical_history`: Hereditary eye diseases (glaucoma, macular degeneration).
- `patient_social_history`: Screen time, smoking habits, occupational risks.
- `clinical_facilities`: Practice locations, NPI, tax IDs, physical addresses.
- `clinical_departments`: Clinic departments and specialty divisions.
- `practitioners`: Optometrists, ophthalmologists, licenses, NPIs.
- `practitioner_credentials`: Board certifications, state licenses, expirations.
- `practitioner_facility_affiliations`: Provider-clinic scheduling matrix.
- `practitioner_schedules`: Office hours and appointment slots.
- `lookup_genders`: Standardized FHIR administrative gender codes.
- `lookup_marital_statuses`: Standardized marital status codes.
- `lookup_contact_types`: Mobile, home, work, fax lookups.
- `lookup_address_types`: Physical, mailing, seasonal lookups.
- `lookup_relationship_types`: Spouse, child, parent lookups.
- `lookup_consent_types`: HIPAA notice, treatment consents.
- `lookup_specialties`: Ophthalmology, Optometry, Cornea, Retina lookups.
- `patient_audit_event_log`: HIPAA access and modification audit trails.
- `patient_telehealth_profiles`: Device readiness and video consult capabilities.
- `patient_biometric_auth_tokens`: Passkey and biometric tokens.
- `patient_communication_logs`: SMS, email, recall communication logs.
- `patient_documents`: Scanned insurance cards, IDs, referral letters.
- `patient_recall_registry`: Periodic eye exam recall tracking.
- `patient_custom_attributes`: Extensible key-value clinical attributes.
- `patient_satisfaction_surveys`: Post-visit CSAT and patient feedback.
- `patient_portal_notifications`: Direct messages sent to patient portal.
- `patient_membership_tiers`: Vision wellness club memberships.
- `patient_referral_sources`: Inbound marketing and PCP referral tracking.
- `patient_external_federations`: Single Sign-On (Azure AD B2C, Google).

### 2.2 Schema: `clinical` (55 Tables)
- Covers master visits, ambulatory encounters, SOAP notes, vital signs, physical exam adnexa, laboratory orders, diagnostic imaging (OCT, Fundus photography DICOM studies), care plans, and surgical consents.

### 2.3 Schema: `diagnostics_procedures` (40 Tables)
- Houses master catalogs for ICD-10-CM (ophthalmic and systemic), SNOMED-CT clinical hierarchies, CPT procedure codes with RVUs, surgical OR suite logs, implantable intraocular lens (IOL) serial tracking, and laser treatment dosimetry parameters.

### 2.4 Schema: `pharmacy_medications` (35 Tables)
- Master National Drug Code (NDC) directory, active prescriptions, refills authorized vs remaining, in-clinic dilating drop administration records, pharmacy network directory, and Surescripts e-prescribing transmission audit logs.

### 2.5 Schema: `optometry_ophthalmology` (45 Tables)
- **Eye Care Core**: Manifest & cycloplegic refractions (OD/OS sphere, cylinder, axis, add, prism), visual acuity exams (Snellen/logMAR unaided and BCVA), intraocular pressure tonometry (Goldmann applanation), slit lamp anterior exams, dilated fundus examinations, spectacle lens prescriptions, contact lens fitting specifications, and dispensary retail lab manufacturing tracking.

### 2.6 Schema: `crm_billing_insurance` (50 Tables)
- Synchronized Salesforce CRM entities (Accounts, Leads, Cases), Vision & Major Medical insurance payer directories, 270/271 real-time eligibility checks, medical invoices, line items, patient payments (credit card, HSA/FSA), EDI 837 electronic claims, and remittance denial logs.

### 2.7 Schema: `metadata_ops` (30 Tables)
- Migration batch control ledger, table manifest catalog, incremental watermark registry, data quality quarantine log, automated source-to-target reconciliation audit ledger, and pipeline execution telemetry.
