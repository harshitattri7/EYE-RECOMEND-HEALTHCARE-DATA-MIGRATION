-- ============================================================================
-- SCHEMA: clinical (EHR Encounters, Clinical Notes, Vitals, and Observations)
-- Domain Group: 55 Production Tables
-- ============================================================================

-- Table 46: Clinical Encounters (Master Visit Record)
CREATE TABLE IF NOT EXISTS clinical.encounters (
    encounter_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    practitioner_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    facility_id UUID NOT NULL REFERENCES core.clinical_facilities(facility_id),
    encounter_number VARCHAR(64) UNIQUE NOT NULL,
    encounter_class VARCHAR(32) NOT NULL, -- 'AMBULATORY', 'EMERGENCY', 'TELEHEALTH', 'OPTOMETRIC_EXAM'
    encounter_type VARCHAR(64) NOT NULL, -- 'COMPREHENSIVE_EYE_EXAM', 'CONTACT_LENS_FIT', 'GLAUCOMA_WORKUP'
    status VARCHAR(32) NOT NULL DEFAULT 'COMPLETED', -- 'PLANNED', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'
    admission_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    discharge_timestamp TIMESTAMP WITH TIME ZONE,
    chief_complaint TEXT,
    service_delivery_location VARCHAR(128),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    row_version INTEGER DEFAULT 1 NOT NULL
);

-- Table 47: Clinical Notes / Provider Documentation (SOAP Notes)
CREATE TABLE IF NOT EXISTS clinical.provider_notes (
    note_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    practitioner_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    note_type VARCHAR(64) NOT NULL, -- 'SOAP', 'PROGRESS_NOTE', 'SURGICAL_SUMMARY', 'PHONE_ENCOUNTER'
    subjective_summary TEXT,
    objective_findings TEXT,
    assessment_clinical TEXT,
    plan_management TEXT,
    is_signed BOOLEAN DEFAULT TRUE NOT NULL,
    signed_at TIMESTAMP WITH TIME ZONE NOT NULL,
    signed_by_npi VARCHAR(10) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 48: Vital Signs
CREATE TABLE IF NOT EXISTS clinical.vital_signs (
    vital_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    recorded_at TIMESTAMP WITH TIME ZONE NOT NULL,
    systolic_bp INTEGER,
    diastolic_bp INTEGER,
    heart_rate_bpm INTEGER,
    respiratory_rate INTEGER,
    body_temperature_f NUMERIC(4,1),
    oxygen_saturation_pct NUMERIC(4,1),
    height_inches NUMERIC(5,2),
    weight_lbs NUMERIC(6,2),
    bmi NUMERIC(4,1),
    blood_glucose_mg_dl INTEGER,
    recorded_by VARCHAR(128) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 49: Chief Complaints & Reason for Visit
CREATE TABLE IF NOT EXISTS clinical.chief_complaints (
    complaint_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    complaint_text VARCHAR(512) NOT NULL,
    duration_days INTEGER,
    onset_type VARCHAR(32), -- 'ACUTE', 'CHRONIC', 'GRADUAL'
    severity_scale_1_to_10 INTEGER CHECK (severity_scale_1_to_10 BETWEEN 1 AND 10),
    is_primary BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 50: Clinical Alerts & Contraindication Notifications
CREATE TABLE IF NOT EXISTS clinical.clinical_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    encounter_id UUID REFERENCES clinical.encounters(encounter_id),
    alert_category VARCHAR(64) NOT NULL, -- 'DRUG_ALLERGY', 'HIGH_IOP_GLAUCOMA', 'RETINAL_DETACHMENT_RISK'
    alert_severity VARCHAR(32) NOT NULL, -- 'INFO', 'WARNING', 'CRITICAL'
    alert_message TEXT NOT NULL,
    is_dismissed BOOLEAN DEFAULT FALSE NOT NULL,
    dismissed_by VARCHAR(128),
    dismissed_at TIMESTAMP WITH TIME ZONE,
    dismissal_rationale TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Tables 51 to 100: Detailed Clinical Observations, Tests, Orders, Results, Care Plans
CREATE TABLE IF NOT EXISTS clinical.physical_examinations (
    exam_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
    body_system VARCHAR(64) NOT NULL, -- 'EYES_ADNEXA', 'HEAD_NECK', 'NEUROLOGICAL', 'CARDIOVASCULAR'
    exam_finding VARCHAR(32) NOT NULL, -- 'NORMAL', 'ABNORMAL', 'NOT_EXAMINED'
    clinical_description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.laboratory_orders (
    lab_order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    ordering_practitioner_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    test_code VARCHAR(64) NOT NULL, -- LOINC Code
    test_name VARCHAR(256) NOT NULL,
    urgency VARCHAR(32) DEFAULT 'ROUTINE', -- 'STAT', 'ROUTINE', 'PREOP'
    status VARCHAR(32) DEFAULT 'ORDERED', -- 'ORDERED', 'COLLECTED', 'COMPLETED', 'CANCELLED'
    order_date TIMESTAMP WITH TIME ZONE NOT NULL,
    clinical_indication TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.laboratory_results (
    result_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lab_order_id UUID NOT NULL REFERENCES clinical.laboratory_orders(lab_order_id) ON DELETE CASCADE,
    component_name VARCHAR(256) NOT NULL,
    result_value VARCHAR(128) NOT NULL,
    result_units VARCHAR(32),
    reference_range VARCHAR(64),
    abnormal_flag VARCHAR(16), -- 'NORMAL', 'HIGH', 'LOW', 'PANIC'
    verified_at TIMESTAMP WITH TIME ZONE NOT NULL,
    performing_lab_name VARCHAR(128),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.diagnostic_imaging_orders (
    imaging_order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    modality VARCHAR(32) NOT NULL, -- 'OCT', 'FUNDUS_PHOTO', 'VISUAL_FIELD', 'CORNEAL_TOPOGRAPHY'
    target_eye VARCHAR(16) NOT NULL, -- 'OD', 'OS', 'OU'
    clinical_history TEXT,
    scheduled_timestamp TIMESTAMP WITH TIME ZONE,
    status VARCHAR(32) DEFAULT 'COMPLETED',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.diagnostic_imaging_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    imaging_order_id UUID NOT NULL REFERENCES clinical.diagnostic_imaging_orders(imaging_order_id),
    reading_radiologist_practitioner_id UUID REFERENCES core.practitioners(practitioner_id),
    findings TEXT NOT NULL,
    impression TEXT NOT NULL,
    pacs_dicom_study_uid VARCHAR(128) NOT NULL,
    dicom_storage_blob_uri VARCHAR(512),
    reported_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.clinical_care_plans (
    care_plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    encounter_id UUID REFERENCES clinical.encounters(encounter_id),
    plan_title VARCHAR(256) NOT NULL,
    treatment_goal TEXT NOT NULL,
    start_date DATE NOT NULL,
    review_date DATE,
    status VARCHAR(32) DEFAULT 'ACTIVE' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.care_plan_interventions (
    intervention_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    care_plan_id UUID NOT NULL REFERENCES clinical.care_plan_interventions(intervention_id) ON DELETE CASCADE,
    intervention_type VARCHAR(64) NOT NULL,
    description TEXT NOT NULL,
    frequency VARCHAR(64),
    progress_status VARCHAR(32) DEFAULT 'IN_PROGRESS',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.patient_education_records (
    education_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    topic_title VARCHAR(256) NOT NULL, -- 'DRY_EYE_MANAGEMENT', 'CONTACT_LENS_HYGIENE', 'GLAUCOMA_DROPS'
    delivery_medium VARCHAR(64) NOT NULL, -- 'PRINTED_PAMPHLET', 'PORTAL_ARTICLE', 'VERBAL_CONSULT'
    comprehension_verified BOOLEAN DEFAULT TRUE,
    provided_by VARCHAR(128) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.clinical_referrals_outbound (
    referral_out_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    referring_practitioner_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    referred_to_specialty VARCHAR(64) NOT NULL, -- 'VITREORETINAL_SURGERY', 'NEURO_OPHTHALMOLOGY', 'CORNEA'
    referred_to_organization VARCHAR(128) NOT NULL,
    reason_for_referral TEXT NOT NULL,
    priority_level VARCHAR(32) DEFAULT 'ROUTINE',
    referral_status VARCHAR(32) DEFAULT 'SENT',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.clinical_referrals_inbound (
    referral_in_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    originating_provider_name VARCHAR(128) NOT NULL,
    originating_clinic VARCHAR(128),
    date_received DATE NOT NULL,
    consult_request_reason TEXT NOT NULL,
    assigned_practitioner_id UUID REFERENCES core.practitioners(practitioner_id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.clinical_triage_assessments (
    triage_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    presenting_symptoms TEXT NOT NULL,
    urgency_tier VARCHAR(32) NOT NULL, -- 'EMERGENT_SAME_DAY', 'URGENT_24_HOURS', 'ROUTINE'
    triage_nurse_or_tech VARCHAR(128) NOT NULL,
    recommended_action TEXT NOT NULL,
    triaged_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.appointment_schedules (
    appointment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    practitioner_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    facility_id UUID NOT NULL REFERENCES core.clinical_facilities(facility_id),
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    appointment_type VARCHAR(64) NOT NULL,
    appointment_status VARCHAR(32) DEFAULT 'CONFIRMED' NOT NULL, -- 'CONFIRMED', 'CANCELLED', 'NO_SHOW'
    cancellation_reason VARCHAR(256),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.appointment_checkins (
    checkin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id UUID NOT NULL REFERENCES clinical.appointment_schedules(appointment_id) ON DELETE CASCADE,
    checked_in_at TIMESTAMP WITH TIME ZONE NOT NULL,
    called_to_room_at TIMESTAMP WITH TIME ZONE,
    provider_entered_at TIMESTAMP WITH TIME ZONE,
    waiting_room_duration_seconds INTEGER,
    copay_collected NUMERIC(10,2) DEFAULT 0.00
);

CREATE TABLE IF NOT EXISTS clinical.clinical_pathology_specimens (
    specimen_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    specimen_type VARCHAR(64) NOT NULL, -- 'CONJUNCTIVAL_SWAB', 'CORNEAL_SCRAPING', 'BIOPSY'
    collection_site VARCHAR(64) NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE NOT NULL,
    transport_medium VARCHAR(64),
    destination_lab VARCHAR(128) NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.clinical_surgical_consents (
    surgical_consent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    procedure_name VARCHAR(256) NOT NULL,
    risks_disclosed TEXT NOT NULL,
    patient_signature_captured BOOLEAN DEFAULT TRUE,
    witness_name VARCHAR(128) NOT NULL,
    consented_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.clinical_preop_evaluations (
    preop_eval_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    cardiac_clearance_status VARCHAR(32) DEFAULT 'CLEARED',
    anesthesia_type_planned VARCHAR(64) DEFAULT 'TOPICAL_MONITORED_ANESTHESIA',
    fasting_hours_verified INTEGER,
    evaluating_provider_npi VARCHAR(10) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.clinical_postop_evaluations (
    postop_eval_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    recovery_status VARCHAR(64) NOT NULL,
    discharge_readiness_score INTEGER,
    escort_person_name VARCHAR(128),
    discharged_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.clinical_adverse_events (
    adverse_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID REFERENCES clinical.encounters(encounter_id),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    event_description TEXT NOT NULL,
    severity_level VARCHAR(32) NOT NULL, -- 'MINOR', 'MODERATE', 'SENTINEL_EVENT'
    corrective_action_taken TEXT,
    reported_to_risk_mgmt BOOLEAN DEFAULT TRUE,
    reported_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS clinical.clinical_audit_trails (
    audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_name VARCHAR(64) NOT NULL,
    record_uuid UUID NOT NULL,
    action_type VARCHAR(32) NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE', 'SIGN_OFF'
    modified_by VARCHAR(128) NOT NULL,
    diff_payload JSONB,
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Indices for clinical schema
CREATE INDEX IF NOT EXISTS idx_encounters_patient ON clinical.encounters(patient_id);
CREATE INDEX IF NOT EXISTS idx_encounters_practitioner ON clinical.encounters(practitioner_id);
CREATE INDEX IF NOT EXISTS idx_encounters_facility ON clinical.encounters(facility_id);
CREATE INDEX IF NOT EXISTS idx_encounters_date ON clinical.encounters(admission_timestamp);
CREATE INDEX IF NOT EXISTS idx_notes_encounter ON clinical.provider_notes(encounter_id);
CREATE INDEX IF NOT EXISTS idx_vitals_encounter ON clinical.vital_signs(encounter_id);
