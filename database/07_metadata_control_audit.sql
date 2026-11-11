-- ============================================================================
-- SCHEMA: metadata_ops (Migration Control, Watermarks, DQ Quarantine & Audit)
-- Domain Group: 30+ Production Tables
-- ============================================================================

-- Table 271: Migration Master Batch Execution Control
CREATE TABLE IF NOT EXISTS metadata_ops.batch_control_ledger (
    batch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_name VARCHAR(128) NOT NULL,
    migration_phase VARCHAR(64) NOT NULL, -- 'HISTORICAL_INIT', 'INCREMENTAL_CATCHUP', 'PRODUCTION_CUTOVER'
    source_system VARCHAR(32) NOT NULL,   -- 'DRUPAL_MARIADB', 'SALESFORCE_CRM', 'ALL'
    execution_status VARCHAR(32) DEFAULT 'RUNNING' NOT NULL, -- 'RUNNING', 'COMPLETED', 'FAILED', 'VALIDATED'
    start_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    end_timestamp TIMESTAMP WITH TIME ZONE,
    total_tables_processed INTEGER DEFAULT 0 NOT NULL,
    total_records_ingested BIGINT DEFAULT 0 NOT NULL,
    total_records_inserted BIGINT DEFAULT 0 NOT NULL,
    total_records_updated BIGINT DEFAULT 0 NOT NULL,
    total_records_quarantined BIGINT DEFAULT 0 NOT NULL,
    triggered_by VARCHAR(128) DEFAULT 'ADF_TRIGGER' NOT NULL
);

-- Table 272: Table Manifest Catalog (Ecosystem Registry of 300+ Production Tables)
CREATE TABLE IF NOT EXISTS metadata_ops.table_manifest_catalog (
    table_id SERIAL PRIMARY KEY,
    target_schema VARCHAR(64) NOT NULL,
    target_table_name VARCHAR(128) NOT NULL,
    domain_group VARCHAR(64) NOT NULL,
    source_system VARCHAR(64) NOT NULL,
    source_table_or_entity VARCHAR(128) NOT NULL,
    primary_key_column VARCHAR(64) NOT NULL,
    watermark_column VARCHAR(64),
    load_strategy VARCHAR(32) DEFAULT 'INCREMENTAL_MERGE' NOT NULL, -- 'FULL_OVERWRITE', 'INCREMENTAL_MERGE', 'APPEND_ONLY'
    partition_column VARCHAR(64),
    expected_sla_minutes INTEGER DEFAULT 30 NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    CONSTRAINT uq_manifest_table UNIQUE (target_schema, target_table_name)
);

-- Table 273: High-Watermark Incremental Sync Registry
CREATE TABLE IF NOT EXISTS metadata_ops.watermark_registry (
    watermark_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_id INTEGER NOT NULL REFERENCES metadata_ops.table_manifest_catalog(table_id) ON DELETE CASCADE,
    last_processed_watermark_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    last_processed_watermark_id VARCHAR(128),
    last_sync_batch_id UUID REFERENCES metadata_ops.batch_control_ledger(batch_id),
    sync_status VARCHAR(32) DEFAULT 'SYNCED' NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 274: Data Quality Quarantine / Rejections Ledger
CREATE TABLE IF NOT EXISTS metadata_ops.dq_quarantine_records (
    quarantine_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID REFERENCES metadata_ops.batch_control_ledger(batch_id),
    target_schema VARCHAR(64) NOT NULL,
    target_table_name VARCHAR(128) NOT NULL,
    source_record_key VARCHAR(256) NOT NULL,
    failed_rule_name VARCHAR(128) NOT NULL, -- 'NULL_MRN_CHECK', 'INVALID_DOB_RANGE', 'ORPHAN_PATIENT_FK'
    rule_severity VARCHAR(32) NOT NULL,     -- 'BLOCKING', 'WARNING', 'ANOMALY'
    raw_payload_json JSONB NOT NULL,
    rejection_reason TEXT NOT NULL,
    is_resolved BOOLEAN DEFAULT FALSE NOT NULL,
    resolution_notes TEXT,
    quarantined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 275: Source-to-Target Reconciliation Audit Ledger
CREATE TABLE IF NOT EXISTS metadata_ops.reconciliation_audit_ledger (
    reconciliation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID REFERENCES metadata_ops.batch_control_ledger(batch_id),
    target_schema VARCHAR(64) NOT NULL,
    target_table_name VARCHAR(128) NOT NULL,
    source_record_count BIGINT NOT NULL,
    target_record_count BIGINT NOT NULL,
    delta_record_count BIGINT GENERATED ALWAYS AS (target_record_count - source_record_count) STORED,
    source_checksum_hash VARCHAR(64),
    target_checksum_hash VARCHAR(64),
    checksum_match BOOLEAN DEFAULT TRUE NOT NULL,
    variance_percentage NUMERIC(8,4) GENERATED ALWAYS AS (
        CASE WHEN source_record_count = 0 THEN 0.0000
             ELSE ABS((target_record_count - source_record_count)::NUMERIC / source_record_count::NUMERIC) * 100
        END
    ) STORED,
    reconciliation_verdict VARCHAR(32) NOT NULL, -- 'PASS', 'FAIL_THRESHOLD_EXCEEDED', 'WARNING'
    audited_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 276: Pipeline Heartbeat & Telemetry Events
CREATE TABLE IF NOT EXISTS metadata_ops.pipeline_telemetry_events (
    telemetry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID REFERENCES metadata_ops.batch_control_ledger(batch_id),
    component_name VARCHAR(128) NOT NULL, -- 'ADF_PL_INGESTION', 'DATABRICKS_SPARK_SILVER', 'POSTGRES_BULK_LOADER'
    event_level VARCHAR(16) NOT NULL,      -- 'INFO', 'WARN', 'ERROR'
    duration_milliseconds BIGINT,
    memory_usage_mb NUMERIC(10,2),
    cpu_utilization_pct NUMERIC(5,2),
    message TEXT NOT NULL,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 277: Schema Drift & Evolution Audit
CREATE TABLE IF NOT EXISTS metadata_ops.schema_drift_history (
    drift_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name VARCHAR(128) NOT NULL,
    drift_type VARCHAR(64) NOT NULL, -- 'COLUMN_ADDED', 'TYPE_EXPANDED', 'NULLABLE_ALTERED'
    column_name VARCHAR(128) NOT NULL,
    old_data_type VARCHAR(64),
    new_data_type VARCHAR(64),
    action_taken VARCHAR(128) NOT NULL,
    detected_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 278: Production Cutover Sign-off Checklist
CREATE TABLE IF NOT EXISTS metadata_ops.production_cutover_signoffs (
    signoff_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phase_step_name VARCHAR(128) NOT NULL,
    stakeholder_role VARCHAR(64) NOT NULL, -- 'DATA_ARCHITECT', 'LEAD_QA', 'CLINICAL_PRODUCT_OWNER', 'VP_ENGINEERING'
    stakeholder_name VARCHAR(128) NOT NULL,
    approval_status VARCHAR(32) NOT NULL, -- 'APPROVED', 'REJECTED', 'CONDITIONAL'
    signoff_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    comments TEXT
);

-- Seed metadata manifest with representative mappings for 300+ tables
INSERT INTO metadata_ops.table_manifest_catalog (target_schema, target_table_name, domain_group, source_system, source_table_or_entity, primary_key_column, watermark_column, load_strategy)
VALUES
('core', 'master_patient_index', 'Core Demographics', 'DRUPAL_MARIADB & SALESFORCE', 'patients + Contact', 'mpi_id', 'updated_at', 'INCREMENTAL_MERGE'),
('core', 'patients', 'Core Demographics', 'DRUPAL_MARIADB', 'field_data_patient_profile', 'patient_id', 'changed', 'INCREMENTAL_MERGE'),
('core', 'patient_contacts', 'Core Demographics', 'DRUPAL_MARIADB', 'field_data_patient_contact', 'contact_id', 'changed', 'INCREMENTAL_MERGE'),
('core', 'patient_addresses', 'Core Demographics', 'DRUPAL_MARIADB', 'field_data_patient_address', 'address_id', 'changed', 'INCREMENTAL_MERGE'),
('clinical', 'encounters', 'Clinical EHR', 'DRUPAL_MARIADB', 'node_clinical_encounter', 'encounter_id', 'changed', 'INCREMENTAL_MERGE'),
('clinical', 'vital_signs', 'Clinical EHR', 'DRUPAL_MARIADB', 'field_data_vitals', 'vital_id', 'created', 'APPEND_ONLY'),
('diagnostics_procedures', 'patient_diagnoses', 'Diagnostics', 'DRUPAL_MARIADB', 'field_data_icd_diagnosis', 'diagnosis_id', 'changed', 'INCREMENTAL_MERGE'),
('pharmacy_medications', 'prescriptions', 'Pharmacy', 'DRUPAL_MARIADB', 'node_optical_prescription', 'prescription_id', 'changed', 'INCREMENTAL_MERGE'),
('optometry_ophthalmology', 'refractions', 'Eye Exam Refraction', 'DRUPAL_MARIADB', 'field_data_refraction_details', 'refraction_id', 'changed', 'INCREMENTAL_MERGE'),
('optometry_ophthalmology', 'visual_acuity_exams', 'Eye Exam VA', 'DRUPAL_MARIADB', 'field_data_visual_acuity', 'va_exam_id', 'changed', 'INCREMENTAL_MERGE'),
('optometry_ophthalmology', 'tonometry_exams', 'Glaucoma Tonometry', 'DRUPAL_MARIADB', 'field_data_iop_reading', 'tonometry_id', 'changed', 'INCREMENTAL_MERGE'),
('crm_billing_insurance', 'sf_accounts', 'Salesforce CRM', 'SALESFORCE_CRM', 'Account', 'sf_account_id', 'LastModifiedDate', 'INCREMENTAL_MERGE'),
('crm_billing_insurance', 'sf_leads', 'Salesforce CRM', 'SALESFORCE_CRM', 'Lead', 'sf_lead_id', 'LastModifiedDate', 'INCREMENTAL_MERGE'),
('crm_billing_insurance', 'patient_insurance_policies', 'Insurance Billing', 'SALESFORCE_CRM', 'Insurance_Policy__c', 'policy_id', 'LastModifiedDate', 'INCREMENTAL_MERGE'),
('crm_billing_insurance', 'invoices', 'Billing & Claims', 'SALESFORCE_CRM', 'Invoice__c', 'invoice_id', 'LastModifiedDate', 'INCREMENTAL_MERGE')
ON CONFLICT (target_schema, target_table_name) DO NOTHING;
