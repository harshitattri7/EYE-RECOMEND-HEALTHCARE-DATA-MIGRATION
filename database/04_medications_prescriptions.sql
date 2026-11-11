-- ============================================================================
-- SCHEMA: pharmacy_medications (NDC Catalog, Ophthalmic Drops & Prescriptions)
-- Domain Group: 35 Production Tables
-- ============================================================================

-- Table 141: National Drug Code (NDC) Master Catalog
CREATE TABLE IF NOT EXISTS pharmacy_medications.catalog_ndc (
    ndc_code VARCHAR(16) PRIMARY KEY, -- 11-digit formatted NDC
    proprietary_name VARCHAR(256) NOT NULL,
    non_proprietary_name VARCHAR(256) NOT NULL,
    dosage_form VARCHAR(64) NOT NULL, -- 'OPHTHALMIC_SOLUTION', 'OPHTHALMIC_SUSPENSION', 'OINTMENT'
    route_name VARCHAR(64) DEFAULT 'OPHTHALMIC' NOT NULL,
    strength VARCHAR(128) NOT NULL,
    active_ingredient_substance TEXT,
    dea_schedule VARCHAR(8) DEFAULT 'NON_CONTROLLED',
    is_preservative_free BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE NOT NULL
);

-- Table 142: Medication Prescriptions (EHR Rx)
CREATE TABLE IF NOT EXISTS pharmacy_medications.prescriptions (
    prescription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    prescriber_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    ndc_code VARCHAR(16) NOT NULL REFERENCES pharmacy_medications.catalog_ndc(ndc_code),
    medication_name VARCHAR(256) NOT NULL,
    dosage_strength VARCHAR(64) NOT NULL,
    sig_instructions TEXT NOT NULL, -- 'Instill 1 drop in OD twice daily for 14 days'
    target_eye VARCHAR(16) NOT NULL, -- 'OD', 'OS', 'OU', 'SYSTEMIC'
    quantity_prescribed NUMERIC(8,2) NOT NULL,
    unit_of_measure VARCHAR(32) DEFAULT 'ML',
    refills_authorized INTEGER DEFAULT 0 NOT NULL,
    refills_remaining INTEGER DEFAULT 0 NOT NULL,
    days_supply INTEGER NOT NULL,
    substitution_permitted BOOLEAN DEFAULT TRUE NOT NULL,
    prescription_status VARCHAR(32) DEFAULT 'ACTIVE' NOT NULL, -- 'ACTIVE', 'COMPLETED', 'DISCONTINUED'
    discontinued_reason TEXT,
    issued_date DATE NOT NULL,
    expiration_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    row_version INTEGER DEFAULT 1 NOT NULL
);

-- Table 143: Dispense and Administration Records
CREATE TABLE IF NOT EXISTS pharmacy_medications.dispense_history (
    dispense_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prescription_id UUID NOT NULL REFERENCES pharmacy_medications.prescriptions(prescription_id) ON DELETE CASCADE,
    dispense_date TIMESTAMP WITH TIME ZONE NOT NULL,
    pharmacy_npi VARCHAR(10) NOT NULL,
    pharmacy_name VARCHAR(128) NOT NULL,
    quantity_dispensed NUMERIC(8,2) NOT NULL,
    days_supply_dispensed INTEGER NOT NULL,
    copay_amount NUMERIC(8,2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 144: In-Clinic Medication Administrations (Dilating Drops, Anesthetics)
CREATE TABLE IF NOT EXISTS pharmacy_medications.in_clinic_administrations (
    admin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    administered_by_practitioner_id UUID REFERENCES core.practitioners(practitioner_id),
    drug_name VARCHAR(128) NOT NULL, -- 'Tropicamide 1%', 'Proparacaine 0.5%', 'Phenylephrine 2.5%'
    eye_instilled VARCHAR(8) NOT NULL, -- 'OD', 'OS', 'OU'
    administered_at TIMESTAMP WITH TIME ZONE NOT NULL,
    time_of_dilation TIMESTAMP WITH TIME ZONE,
    pupil_size_after_dilation_mm NUMERIC(3,1)
);

-- Table 145 to 175: Drug Interactions, Formularies, E-Rx Logs
CREATE TABLE IF NOT EXISTS pharmacy_medications.drug_interactions_catalog (
    interaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drug_concept_a VARCHAR(128) NOT NULL,
    drug_concept_b VARCHAR(128) NOT NULL,
    severity_level VARCHAR(32) NOT NULL, -- 'CONTRAINDICATED', 'MAJOR', 'MODERATE'
    clinical_effect TEXT NOT NULL,
    CONSTRAINT uq_drug_pair UNIQUE (drug_concept_a, drug_concept_b)
);

CREATE TABLE IF NOT EXISTS pharmacy_medications.pharmacy_network_directory (
    pharmacy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    npi VARCHAR(10) UNIQUE NOT NULL,
    ncpdp_id VARCHAR(16) UNIQUE,
    pharmacy_name VARCHAR(128) NOT NULL,
    phone VARCHAR(32) NOT NULL,
    fax VARCHAR(32),
    address VARCHAR(256) NOT NULL,
    city VARCHAR(128) NOT NULL,
    state VARCHAR(64) NOT NULL,
    zip_code VARCHAR(20) NOT NULL,
    is_24_hour BOOLEAN DEFAULT FALSE,
    accepts_e_prescribe BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS pharmacy_medications.eprescribe_audit_log (
    transmission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prescription_id UUID NOT NULL REFERENCES pharmacy_medications.prescriptions(prescription_id),
    surescripts_message_id VARCHAR(128) NOT NULL,
    transmission_status VARCHAR(32) NOT NULL, -- 'SENT', 'VERIFIED_DELIVERED', 'ERROR'
    error_code VARCHAR(64),
    response_payload JSONB,
    transmitted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Indices for medications
CREATE INDEX IF NOT EXISTS idx_prescriptions_patient ON pharmacy_medications.prescriptions(patient_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_ndc ON pharmacy_medications.prescriptions(ndc_code);
CREATE INDEX IF NOT EXISTS idx_prescriptions_status ON pharmacy_medications.prescriptions(prescription_status);
