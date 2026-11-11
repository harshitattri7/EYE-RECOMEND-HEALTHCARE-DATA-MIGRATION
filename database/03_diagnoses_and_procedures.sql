-- ============================================================================
-- SCHEMA: diagnostics_procedures (ICD-10, SNOMED, CPT, Diagnoses & Procedures)
-- Domain Group: 40 Production Tables
-- ============================================================================

-- Table 101: ICD-10-CM Master Reference Catalog
CREATE TABLE IF NOT EXISTS diagnostics_procedures.catalog_icd10 (
    icd10_code VARCHAR(16) PRIMARY KEY,
    short_description VARCHAR(128) NOT NULL,
    long_description TEXT NOT NULL,
    category_code VARCHAR(8) NOT NULL,
    is_billable BOOLEAN DEFAULT TRUE NOT NULL,
    is_ophthalmic BOOLEAN DEFAULT FALSE NOT NULL,
    valid_from DATE DEFAULT '2015-10-01' NOT NULL,
    valid_to DATE
);

-- Table 102: SNOMED-CT Clinical Terms Concept Mapping
CREATE TABLE IF NOT EXISTS diagnostics_procedures.catalog_snomed_ct (
    concept_id BIGINT PRIMARY KEY,
    fully_specified_name VARCHAR(512) NOT NULL,
    semantic_tag VARCHAR(64) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    effective_time DATE NOT NULL
);

-- Table 103: CPT / HCPCS Procedure Codes Catalog
CREATE TABLE IF NOT EXISTS diagnostics_procedures.catalog_cpt_codes (
    cpt_code VARCHAR(10) PRIMARY KEY,
    short_descriptor VARCHAR(128) NOT NULL,
    long_descriptor TEXT NOT NULL,
    category_type VARCHAR(32) NOT NULL, -- 'CATEGORY_I', 'CATEGORY_II', 'HCPCS'
    relative_value_units NUMERIC(6,2) DEFAULT 0.00,
    is_bilateral_eligible BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE NOT NULL
);

-- Table 104: Patient Clinical Diagnoses / Problem List
CREATE TABLE IF NOT EXISTS diagnostics_procedures.patient_diagnoses (
    diagnosis_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    icd10_code VARCHAR(16) NOT NULL REFERENCES diagnostics_procedures.catalog_icd10(icd10_code),
    snomed_concept_id BIGINT REFERENCES diagnostics_procedures.catalog_snomed_ct(concept_id),
    diagnosis_type VARCHAR(32) NOT NULL, -- 'PRIMARY', 'SECONDARY', 'CHRONIC_PROBLEM', 'DIFFERENTIAL'
    clinical_status VARCHAR(32) DEFAULT 'ACTIVE' NOT NULL, -- 'ACTIVE', 'RESOLVED', 'REMISSION', 'RELAPSED'
    laterality VARCHAR(16), -- 'RIGHT_EYE_OD', 'LEFT_EYE_OS', 'BILATERAL_OU', 'NOT_APPLICABLE'
    onset_date DATE,
    resolution_date DATE,
    diagnosing_practitioner_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    clinical_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    row_version INTEGER DEFAULT 1 NOT NULL
);

-- Table 105: Performed Procedures (Surgical & In-Office)
CREATE TABLE IF NOT EXISTS diagnostics_procedures.performed_procedures (
    procedure_instance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    cpt_code VARCHAR(10) NOT NULL REFERENCES diagnostics_procedures.catalog_cpt_codes(cpt_code),
    performing_practitioner_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    procedure_name VARCHAR(256) NOT NULL, -- e.g. 'Phacoemulsification with IOL Implant', 'Laser Trabeculoplasty'
    laterality VARCHAR(16) NOT NULL, -- 'OD', 'OS', 'OU'
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    complications_noted TEXT,
    postop_plan TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 106 to 140: Surgical Logs, Modifiers, Medical Necessity, Anesthesia Details
CREATE TABLE IF NOT EXISTS diagnostics_procedures.procedure_cpt_modifiers (
    modifier_instance_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    procedure_instance_id UUID NOT NULL REFERENCES diagnostics_procedures.performed_procedures(procedure_instance_id) ON DELETE CASCADE,
    modifier_code VARCHAR(4) NOT NULL, -- 'RT', 'LT', '50', '25', '59'
    modifier_description VARCHAR(128) NOT NULL
);

CREATE TABLE IF NOT EXISTS diagnostics_procedures.surgical_or_suites (
    or_suite_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id UUID NOT NULL REFERENCES core.clinical_facilities(facility_id),
    suite_number VARCHAR(32) NOT NULL,
    microscope_model VARCHAR(128),
    phaco_machine_model VARCHAR(128),
    laser_platform VARCHAR(128),
    is_active BOOLEAN DEFAULT TRUE NOT NULL
);

CREATE TABLE IF NOT EXISTS diagnostics_procedures.surgical_case_logs (
    case_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    procedure_instance_id UUID NOT NULL REFERENCES diagnostics_procedures.performed_procedures(procedure_instance_id),
    or_suite_id UUID REFERENCES diagnostics_procedures.surgical_or_suites(or_suite_id),
    primary_surgeon_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    assisting_surgeon_id UUID REFERENCES core.practitioners(practitioner_id),
    anesthesiologist_id UUID REFERENCES core.practitioners(practitioner_id),
    scrub_nurse_name VARCHAR(128),
    circulating_nurse_name VARCHAR(128),
    time_in TIMESTAMP WITH TIME ZONE NOT NULL,
    time_out TIMESTAMP WITH TIME ZONE NOT NULL,
    estimated_blood_loss_ml INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS diagnostics_procedures.implantable_devices_log (
    implant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    procedure_instance_id UUID NOT NULL REFERENCES diagnostics_procedures.performed_procedures(procedure_instance_id),
    device_type VARCHAR(64) NOT NULL, -- 'INTRAOCULAR_LENS_IOL', 'GLAUCOMA_DRAINAGE_SHAVE', 'PUNCTAL_PLUG'
    manufacturer VARCHAR(128) NOT NULL,
    model_number VARCHAR(128) NOT NULL,
    serial_or_lot_number VARCHAR(128) NOT NULL,
    optical_diopter_power NUMERIC(5,2),
    udi_barcode VARCHAR(256),
    eye_implanted VARCHAR(8) NOT NULL -- 'OD', 'OS'
);

CREATE TABLE IF NOT EXISTS diagnostics_procedures.laser_treatment_parameters (
    laser_param_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    procedure_instance_id UUID NOT NULL REFERENCES diagnostics_procedures.performed_procedures(procedure_instance_id),
    laser_type VARCHAR(64) NOT NULL, -- 'ARGON_PHOTOCOAGULATION', 'YAG_CAPSULOTOMY', 'SLT'
    power_mw INTEGER NOT NULL,
    spot_size_microns INTEGER NOT NULL,
    duration_ms INTEGER NOT NULL,
    spot_count INTEGER NOT NULL,
    cumulative_energy_mj NUMERIC(8,2)
);

CREATE TABLE IF NOT EXISTS diagnostics_procedures.diagnostic_biopsies (
    biopsy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    anatomical_location VARCHAR(128) NOT NULL,
    biopsy_technique VARCHAR(64) NOT NULL,
    provisional_path_diagnosis TEXT,
    margin_status VARCHAR(32) -- 'CLEAR', 'INVOLVED'
);

CREATE TABLE IF NOT EXISTS diagnostics_procedures.crosswalk_icd10_to_snomed (
    crosswalk_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    icd10_code VARCHAR(16) NOT NULL,
    snomed_concept_id BIGINT NOT NULL,
    mapping_relationship VARCHAR(64) DEFAULT 'EXACT_EQUIVALENT',
    CONSTRAINT uq_icd_snomed UNIQUE (icd10_code, snomed_concept_id)
);

-- Indices for diagnostics & procedures
CREATE INDEX IF NOT EXISTS idx_diagnoses_patient ON diagnostics_procedures.patient_diagnoses(patient_id);
CREATE INDEX IF NOT EXISTS idx_diagnoses_icd10 ON diagnostics_procedures.patient_diagnoses(icd10_code);
CREATE INDEX IF NOT EXISTS idx_procedures_patient ON diagnostics_procedures.performed_procedures(patient_id);
CREATE INDEX IF NOT EXISTS idx_procedures_cpt ON diagnostics_procedures.performed_procedures(cpt_code);
