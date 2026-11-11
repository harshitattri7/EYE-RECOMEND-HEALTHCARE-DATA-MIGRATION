-- ============================================================================
-- SCHEMA: core (Patient Demographics, Identity, and Master Patient Index)
-- Domain Group: 45 Production Tables
-- ============================================================================

-- Table 1: Master Patient Index (MPI)
CREATE TABLE IF NOT EXISTS core.master_patient_index (
    mpi_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enterprise_patient_id VARCHAR(64) UNIQUE NOT NULL,
    primary_mrn VARCHAR(64) NOT NULL,
    identity_confidence_score NUMERIC(5,2) DEFAULT 100.00,
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
    merged_into_mpi_id UUID REFERENCES core.master_patient_index(mpi_id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    row_version INTEGER DEFAULT 1 NOT NULL
);

-- Table 2: Source System Cross-Reference (MariaDB & Salesforce Identity Mapping)
CREATE TABLE IF NOT EXISTS core.patient_source_cross_reference (
    xref_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mpi_id UUID NOT NULL REFERENCES core.master_patient_index(mpi_id) ON DELETE CASCADE,
    source_system VARCHAR(32) NOT NULL, -- 'DRUPAL_MARIADB', 'SALESFORCE_CRM', 'LEGACY_OPTOM'
    source_record_id VARCHAR(128) NOT NULL,
    source_mrn VARCHAR(64),
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    linked_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_source_record UNIQUE (source_system, source_record_id)
);

-- Table 3: Patient Core Demographics
CREATE TABLE IF NOT EXISTS core.patients (
    patient_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mpi_id UUID NOT NULL REFERENCES core.master_patient_index(mpi_id),
    mrn VARCHAR(64) UNIQUE NOT NULL,
    first_name_encrypted BYTEA,
    last_name_encrypted BYTEA,
    first_name_masked VARCHAR(64) NOT NULL,
    last_name_masked VARCHAR(64) NOT NULL,
    middle_name VARCHAR(64),
    preferred_name VARCHAR(64),
    date_of_birth DATE NOT NULL,
    gender VARCHAR(24) NOT NULL,
    birth_sex VARCHAR(24),
    preferred_pronouns VARCHAR(32),
    ssn_last_four VARCHAR(4),
    primary_language VARCHAR(48) DEFAULT 'English',
    marital_status VARCHAR(32),
    is_deceased BOOLEAN DEFAULT FALSE NOT NULL,
    deceased_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    row_version INTEGER DEFAULT 1 NOT NULL
);

-- Table 4: Contact Information
CREATE TABLE IF NOT EXISTS core.patient_contacts (
    contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    contact_type VARCHAR(32) NOT NULL, -- 'MOBILE', 'HOME', 'WORK', 'EMAIL'
    contact_value VARCHAR(256) NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE NOT NULL,
    preferred_contact_method BOOLEAN DEFAULT FALSE,
    opt_in_sms BOOLEAN DEFAULT FALSE,
    opt_in_email BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 5: Addresses
CREATE TABLE IF NOT EXISTS core.patient_addresses (
    address_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    address_type VARCHAR(32) NOT NULL, -- 'HOME', 'MAILING', 'BILLING', 'TEMPORARY'
    address_line_1 VARCHAR(256) NOT NULL,
    address_line_2 VARCHAR(256),
    city VARCHAR(128) NOT NULL,
    state_province VARCHAR(64) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    country_code VARCHAR(3) DEFAULT 'USA' NOT NULL,
    is_primary BOOLEAN DEFAULT TRUE NOT NULL,
    latitude NUMERIC(10, 6),
    longitude NUMERIC(10, 6),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 6: Emergency Contacts
CREATE TABLE IF NOT EXISTS core.patient_emergency_contacts (
    emergency_contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    contact_name VARCHAR(128) NOT NULL,
    relationship VARCHAR(64) NOT NULL,
    phone_number VARCHAR(32) NOT NULL,
    alt_phone_number VARCHAR(32),
    email VARCHAR(128),
    is_primary BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 7: Legal Guardians & Powers of Attorney
CREATE TABLE IF NOT EXISTS core.patient_guardians (
    guardian_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    guardian_name VARCHAR(128) NOT NULL,
    relationship_type VARCHAR(64) NOT NULL,
    legal_authority_type VARCHAR(64) NOT NULL, -- 'PARENT', 'POA', 'HEALTHCARE_PROXY'
    phone VARCHAR(32) NOT NULL,
    verification_document_url VARCHAR(512),
    effective_start_date DATE NOT NULL,
    effective_end_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 8: Consents & Privacy Acknowledgements (HIPAA)
CREATE TABLE IF NOT EXISTS core.patient_consents (
    consent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    consent_type VARCHAR(64) NOT NULL, -- 'HIPAA_NOTICE', 'TREATMENT', 'DATA_SHARING', 'TELEHEALTH'
    status VARCHAR(32) NOT NULL, -- 'GRANTED', 'REVOKED', 'EXPIRED'
    consent_version VARCHAR(32) NOT NULL,
    signed_at TIMESTAMP WITH TIME ZONE NOT NULL,
    expiration_date DATE,
    signed_by VARCHAR(128) NOT NULL,
    signature_fingerprint VARCHAR(256),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 9: Patient Identifiers (Driver License, State ID, Passport)
CREATE TABLE IF NOT EXISTS core.patient_government_identifiers (
    identifier_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    identifier_type VARCHAR(32) NOT NULL,
    hashed_identifier VARCHAR(128) NOT NULL,
    issuing_state VARCHAR(32),
    issuing_country VARCHAR(3) DEFAULT 'USA',
    expiration_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 10: Patient Portal Credentials & Access Mapping
CREATE TABLE IF NOT EXISTS core.patient_portal_accounts (
    portal_account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    portal_username VARCHAR(128) UNIQUE NOT NULL,
    account_status VARCHAR(32) DEFAULT 'ACTIVE' NOT NULL,
    last_login_at TIMESTAMP WITH TIME ZONE,
    failed_login_attempts INTEGER DEFAULT 0 NOT NULL,
    mfa_enabled BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 11 to 20: Patient Relationships, Preferences, Communication Logs, Notes
CREATE TABLE IF NOT EXISTS core.patient_preferences (
    preference_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    preferred_provider_id UUID,
    preferred_clinic_location_id UUID,
    reminder_preference VARCHAR(32) DEFAULT 'SMS',
    communication_hours VARCHAR(64) DEFAULT 'MORNING',
    interpretive_services_required BOOLEAN DEFAULT FALSE,
    special_accommodations TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_relationships (
    relationship_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    target_patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    relationship_type VARCHAR(64) NOT NULL, -- 'SPOUSE', 'CHILD', 'SIBLING', 'CAREGIVER'
    is_guarantor BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_employer_history (
    employer_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    employer_name VARCHAR(128) NOT NULL,
    occupation VARCHAR(128),
    employment_status VARCHAR(32),
    start_date DATE,
    end_date DATE,
    is_current BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_merge_history (
    merge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    surviving_mpi_id UUID NOT NULL REFERENCES core.master_patient_index(mpi_id),
    retired_mpi_id UUID NOT NULL,
    merge_reason VARCHAR(256) NOT NULL,
    reconciliation_operator VARCHAR(128) NOT NULL,
    merged_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_flags (
    flag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    flag_code VARCHAR(64) NOT NULL, -- 'FALL_RISK', 'INFECTION_CONTROL', 'VIP', 'AGGRESSIVE_BEHAVIOR'
    flag_severity VARCHAR(32) NOT NULL, -- 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
    active_until DATE,
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_allergies_registry (
    allergy_registry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    allergen_type VARCHAR(64) NOT NULL, -- 'DRUG', 'FOOD', 'ENVIRONMENTAL', 'LATEX'
    allergen_code VARCHAR(64),
    allergen_description VARCHAR(256) NOT NULL,
    severity VARCHAR(32) NOT NULL, -- 'MILD', 'MODERATE', 'SEVERE', 'LIFE_THREATENING'
    reaction_symptoms TEXT,
    onsetDate DATE,
    status VARCHAR(32) DEFAULT 'ACTIVE' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_immunization_registry (
    immunization_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    vaccine_code VARCHAR(64) NOT NULL,
    vaccine_name VARCHAR(256) NOT NULL,
    administered_date DATE NOT NULL,
    lot_number VARCHAR(64),
    manufacturer VARCHAR(128),
    expiration_date DATE,
    administration_site VARCHAR(64),
    route VARCHAR(64),
    dose_amount VARCHAR(32),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_care_team_members (
    care_team_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    provider_id UUID NOT NULL,
    provider_role VARCHAR(64) NOT NULL, -- 'PRIMARY_OPTOMETRIST', 'OPHTHALMOLOGIST_SURGEON', 'PCP'
    is_lead BOOLEAN DEFAULT FALSE NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_family_medical_history (
    family_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    relationship VARCHAR(64) NOT NULL,
    condition_code VARCHAR(64),
    condition_name VARCHAR(256) NOT NULL, -- 'GLAUCOMA', 'MACULAR_DEGENERATION', 'DIABETES'
    age_at_onset INTEGER,
    is_deceased BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_social_history (
    social_history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    smoking_status VARCHAR(64),
    alcohol_use VARCHAR(64),
    screen_time_hours_daily NUMERIC(4,1),
    occupational_hazard_details TEXT,
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Tables 21 to 45: Supporting Core Dimensions, Lookups, Facility Locations & System Mappings
CREATE TABLE IF NOT EXISTS core.clinical_facilities (
    facility_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_code VARCHAR(32) UNIQUE NOT NULL,
    facility_name VARCHAR(128) NOT NULL,
    facility_type VARCHAR(64) NOT NULL, -- 'OPTOMETRY_CLINIC', 'SURGICAL_CENTER', 'OPTICAL_DISPENSARY'
    npi_number VARCHAR(10) UNIQUE,
    tax_id VARCHAR(32),
    address_line VARCHAR(256) NOT NULL,
    city VARCHAR(128) NOT NULL,
    state VARCHAR(64) NOT NULL,
    zip_code VARCHAR(20) NOT NULL,
    phone VARCHAR(32) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.clinical_departments (
    department_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id UUID NOT NULL REFERENCES core.clinical_facilities(facility_id),
    department_code VARCHAR(32) NOT NULL,
    department_name VARCHAR(128) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.practitioners (
    practitioner_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    npi VARCHAR(10) UNIQUE NOT NULL,
    first_name VARCHAR(64) NOT NULL,
    last_name VARCHAR(64) NOT NULL,
    license_number VARCHAR(64) NOT NULL,
    license_state VARCHAR(32) NOT NULL,
    primary_specialty VARCHAR(64) NOT NULL, -- 'OPTOMETRY', 'OPHTHALMOLOGY', 'RETINA_SPECIALIST'
    email VARCHAR(128) UNIQUE NOT NULL,
    phone VARCHAR(32),
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.practitioner_credentials (
    credential_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    practitioner_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id) ON DELETE CASCADE,
    credential_type VARCHAR(64) NOT NULL,
    issuing_board VARCHAR(128) NOT NULL,
    issued_date DATE NOT NULL,
    expiration_date DATE NOT NULL,
    verification_status VARCHAR(32) DEFAULT 'VERIFIED' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.practitioner_facility_affiliations (
    affiliation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    practitioner_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    facility_id UUID NOT NULL REFERENCES core.clinical_facilities(facility_id),
    start_date DATE NOT NULL,
    end_date DATE,
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.practitioner_schedules (
    schedule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    practitioner_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    facility_id UUID NOT NULL REFERENCES core.clinical_facilities(facility_id),
    day_of_week INTEGER NOT NULL, -- 1=Monday, 7=Sunday
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    slot_duration_minutes INTEGER DEFAULT 20 NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL
);

CREATE TABLE IF NOT EXISTS core.lookup_genders (
    code VARCHAR(24) PRIMARY KEY,
    display_name VARCHAR(64) NOT NULL,
    fhir_mapping_code VARCHAR(32)
);

CREATE TABLE IF NOT EXISTS core.lookup_marital_statuses (
    code VARCHAR(32) PRIMARY KEY,
    display_name VARCHAR(64) NOT NULL
);

CREATE TABLE IF NOT EXISTS core.lookup_contact_types (
    code VARCHAR(32) PRIMARY KEY,
    description VARCHAR(128) NOT NULL
);

CREATE TABLE IF NOT EXISTS core.lookup_address_types (
    code VARCHAR(32) PRIMARY KEY,
    description VARCHAR(128) NOT NULL
);

CREATE TABLE IF NOT EXISTS core.lookup_relationship_types (
    code VARCHAR(64) PRIMARY KEY,
    description VARCHAR(128) NOT NULL
);

CREATE TABLE IF NOT EXISTS core.lookup_consent_types (
    code VARCHAR(64) PRIMARY KEY,
    description VARCHAR(256) NOT NULL
);

CREATE TABLE IF NOT EXISTS core.lookup_specialties (
    code VARCHAR(64) PRIMARY KEY,
    description VARCHAR(256) NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_audit_event_log (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    event_type VARCHAR(64) NOT NULL, -- 'VIEW', 'UPDATE', 'EXPORT', 'DECRYPT_PII'
    performed_by VARCHAR(128) NOT NULL,
    ip_address INET,
    details JSONB,
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_telehealth_profiles (
    telehealth_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    device_type VARCHAR(64),
    preferred_video_platform VARCHAR(64) DEFAULT 'WEBRTC',
    bandwidth_test_result VARCHAR(32),
    last_verified_at TIMESTAMP WITH TIME ZONE,
    is_eligible BOOLEAN DEFAULT TRUE NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_biometric_auth_tokens (
    token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    token_hash VARCHAR(256) NOT NULL,
    device_fingerprint VARCHAR(256) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_communication_logs (
    comm_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    channel VARCHAR(32) NOT NULL, -- 'SMS', 'EMAIL', 'IVR', 'PORTAL'
    direction VARCHAR(16) NOT NULL, -- 'OUTBOUND', 'INBOUND'
    message_type VARCHAR(64) NOT NULL, -- 'APPOINTMENT_REMINDER', 'ORDER_READY', 'RECALL'
    status VARCHAR(32) NOT NULL, -- 'DELIVERED', 'FAILED', 'BOUNCED'
    delivery_timestamp TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_documents (
    document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    document_category VARCHAR(64) NOT NULL, -- 'ID_CARD', 'INSURANCE_CARD', 'REFERRAL', 'HISTORICAL_EHR'
    file_name VARCHAR(256) NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    mime_type VARCHAR(64) NOT NULL,
    storage_blob_uri VARCHAR(512) NOT NULL,
    sha256_hash VARCHAR(64) NOT NULL,
    uploaded_by VARCHAR(128) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_recall_registry (
    recall_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    recall_reason VARCHAR(64) NOT NULL, -- 'ANNUAL_EYE_EXAM', 'DIABETIC_EYE_CHECK', 'GLAUCOMA_FOLLOWUP'
    due_date DATE NOT NULL,
    status VARCHAR(32) DEFAULT 'PENDING' NOT NULL, -- 'PENDING', 'NOTIFIED', 'SCHEDULED', 'DISMISSED'
    last_contacted_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_custom_attributes (
    attribute_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    attr_key VARCHAR(64) NOT NULL,
    attr_value TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_patient_attr UNIQUE (patient_id, attr_key)
);

CREATE TABLE IF NOT EXISTS core.patient_satisfaction_surveys (
    survey_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    visit_id UUID,
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    feedback TEXT,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_portal_notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    portal_account_id UUID NOT NULL REFERENCES core.patient_portal_accounts(portal_account_id),
    title VARCHAR(256) NOT NULL,
    body TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_membership_tiers (
    membership_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    tier_level VARCHAR(32) DEFAULT 'STANDARD' NOT NULL, -- 'STANDARD', 'VISION_PLUS', 'VIP_PLATINUM'
    enrollment_date DATE NOT NULL,
    expiration_date DATE,
    auto_renew BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_referral_sources (
    referral_source_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    referral_type VARCHAR(64) NOT NULL, -- 'PCP_REFERRAL', 'ONLINE_SEARCH', 'WORD_OF_MOUTH', 'INSURANCE_DIRECTORY'
    referring_physician_name VARCHAR(128),
    referring_npi VARCHAR(10),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS core.patient_external_federations (
    federation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    idp_provider VARCHAR(64) NOT NULL, -- 'AZURE_AD_B2C', 'GOOGLE_OAUTH', 'APPLE_SIGNIN'
    subject_identifier VARCHAR(256) NOT NULL,
    linked_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT uq_federation UNIQUE (idp_provider, subject_identifier)
);

-- Indices for core schema optimization
CREATE INDEX IF NOT EXISTS idx_patients_mpi ON core.patients(mpi_id);
CREATE INDEX IF NOT EXISTS idx_patients_mrn ON core.patients(mrn);
CREATE INDEX IF NOT EXISTS idx_patients_dob ON core.patients(date_of_birth);
CREATE INDEX IF NOT EXISTS idx_xref_source ON core.patient_source_cross_reference(source_system, source_record_id);
CREATE INDEX IF NOT EXISTS idx_contacts_patient ON core.patient_contacts(patient_id);
CREATE INDEX IF NOT EXISTS idx_addresses_patient ON core.patient_addresses(patient_id);
