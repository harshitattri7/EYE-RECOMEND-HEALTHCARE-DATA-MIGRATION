-- ============================================================================
-- EYE RECOMMEND HEALTHCARE DATA MIGRATION PLATFORM
-- Target Database Initialization Script (Azure Database for PostgreSQL Flexible Server)
-- ============================================================================

-- Enforce standard UTF-8 encoding and timezone configuration
SET client_encoding = 'UTF8';
SET timezone = 'UTC';

-- Install required extensions for UUID generation, cryptographic hashing, and indexing
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "btree_gist";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Create Enterprise Architectural Schemas
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS clinical;
CREATE SCHEMA IF NOT EXISTS diagnostics_procedures;
CREATE SCHEMA IF NOT EXISTS pharmacy_medications;
CREATE SCHEMA IF NOT EXISTS optometry_ophthalmology;
CREATE SCHEMA IF NOT EXISTS crm_billing_insurance;
CREATE SCHEMA IF NOT EXISTS metadata_ops;

-- Comment on Schemas
COMMENT ON SCHEMA core IS 'Master Patient Index (MPI), patient demographics, consents, identity mapping, and contacts';
COMMENT ON SCHEMA clinical IS 'Electronic Health Record (EHR) encounters, vitals, provider notes, and clinical events';
COMMENT ON SCHEMA diagnostics_procedures IS 'Clinical coding catalogs (ICD-10, SNOMED, CPT), diagnoses, and surgical procedures';
COMMENT ON SCHEMA pharmacy_medications IS 'Prescriptions, NDC medication catalog, dispense logs, and allergy reactions';
COMMENT ON SCHEMA optometry_ophthalmology IS 'Ophthalmic exams, refraction (OD/OS), IOP tonometry, lens specs, and optical orders';
COMMENT ON SCHEMA crm_billing_insurance IS 'Salesforce synchronized accounts, leads, insurance policies, claims, and invoices';
COMMENT ON SCHEMA metadata_ops IS 'Migration batch control, watermark state, data quality quarantine, and reconciliation';

-- Base audit trigger function for recording row versioning and update timestamps
CREATE OR REPLACE FUNCTION metadata_ops.fn_set_timestamp_and_version()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    NEW.row_version = OLD.row_version + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
