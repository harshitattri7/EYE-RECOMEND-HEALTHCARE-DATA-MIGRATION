-- ============================================================================
-- SCHEMA: crm_billing_insurance (Salesforce CRM Sync, Insurance, Claims & Billing)
-- Domain Group: 50 Production Tables
-- ============================================================================

-- Table 221: Salesforce Synchronized Accounts (Business & Partner Practices)
CREATE TABLE IF NOT EXISTS crm_billing_insurance.sf_accounts (
    sf_account_id VARCHAR(18) PRIMARY KEY, -- Salesforce 18-char Case-Insensitive Id
    account_name VARCHAR(256) NOT NULL,
    account_type VARCHAR(64) NOT NULL, -- 'AFFILIATED_CLINIC', 'SUPPLIER_LAB', 'CORPORATE_SPONSOR'
    parent_account_id VARCHAR(18),
    billing_street VARCHAR(256),
    billing_city VARCHAR(128),
    billing_state VARCHAR(64),
    billing_postal_code VARCHAR(20),
    annual_revenue NUMERIC(14,2),
    number_of_employees INTEGER,
    sf_created_date TIMESTAMP WITH TIME ZONE NOT NULL,
    sf_last_modified_date TIMESTAMP WITH TIME ZONE NOT NULL,
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 222: Salesforce Synchronized Leads & Inquiries
CREATE TABLE IF NOT EXISTS crm_billing_insurance.sf_leads (
    sf_lead_id VARCHAR(18) PRIMARY KEY,
    first_name VARCHAR(64),
    last_name VARCHAR(64) NOT NULL,
    email VARCHAR(128),
    phone VARCHAR(32),
    lead_source VARCHAR(64), -- 'LASIK_PROMO_WEB', 'EYE_CARE_SEMINAR', 'GOOGLE_SEARCH'
    lead_status VARCHAR(32) NOT NULL, -- 'NEW', 'CONTACTED', 'QUALIFIED', 'CONVERTED'
    is_converted BOOLEAN DEFAULT FALSE NOT NULL,
    converted_patient_id UUID REFERENCES core.patients(patient_id),
    sf_created_date TIMESTAMP WITH TIME ZONE NOT NULL,
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 223: Salesforce Service Cases / Patient Inquiries & Complaints
CREATE TABLE IF NOT EXISTS crm_billing_insurance.sf_cases (
    sf_case_id VARCHAR(18) PRIMARY KEY,
    case_number VARCHAR(32) UNIQUE NOT NULL,
    patient_id UUID REFERENCES core.patients(patient_id),
    subject VARCHAR(256) NOT NULL,
    description TEXT,
    case_type VARCHAR(64) NOT NULL, -- 'BILLING_DISPUTE', 'APPOINTMENT_RESCHEDULE', 'PRESCRIPTION_RECHECK'
    case_priority VARCHAR(32) DEFAULT 'MEDIUM',
    case_status VARCHAR(32) DEFAULT 'CLOSED',
    resolved_at TIMESTAMP WITH TIME ZONE,
    sf_created_date TIMESTAMP WITH TIME ZONE NOT NULL,
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 224: Insurance Payers Master Directory (Vision & Major Medical)
CREATE TABLE IF NOT EXISTS crm_billing_insurance.insurance_payers (
    payer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payer_code VARCHAR(32) UNIQUE NOT NULL, -- e.g. 'PAYER_VSP', 'PAYER_EYEMED', 'PAYER_MEDICARE'
    payer_name VARCHAR(128) NOT NULL,
    payer_type VARCHAR(32) NOT NULL, -- 'VISION_INSURANCE', 'COMMERCIAL_MEDICAL', 'MEDICARE', 'MEDICAID'
    clearinghouse_payer_id VARCHAR(32) NOT NULL, -- Electronic EDI Payer ID (e.g. '00001')
    edi_electronic_claims_supported BOOLEAN DEFAULT TRUE NOT NULL,
    phone VARCHAR(32) NOT NULL,
    claims_submission_address VARCHAR(256) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 225: Patient Insurance Coverage & Policies
CREATE TABLE IF NOT EXISTS crm_billing_insurance.patient_insurance_policies (
    policy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id) ON DELETE CASCADE,
    payer_id UUID NOT NULL REFERENCES crm_billing_insurance.insurance_payers(payer_id),
    policy_number VARCHAR(64) NOT NULL,
    group_number VARCHAR(64),
    coverage_priority VARCHAR(16) NOT NULL, -- 'PRIMARY', 'SECONDARY', 'TERTIARY'
    subscriber_relationship VARCHAR(32) NOT NULL, -- 'SELF', 'SPOUSE', 'CHILD'
    subscriber_name VARCHAR(128) NOT NULL,
    subscriber_dob DATE,
    effective_date DATE NOT NULL,
    termination_date DATE,
    vision_materials_allowance NUMERIC(8,2) DEFAULT 150.00, -- frame allowance
    copay_exam NUMERIC(8,2) DEFAULT 10.00,
    copay_materials NUMERIC(8,2) DEFAULT 25.00,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    row_version INTEGER DEFAULT 1 NOT NULL
);

-- Table 226: Real-Time Eligibility Verification Logs (270/271 EDI)
CREATE TABLE IF NOT EXISTS crm_billing_insurance.eligibility_checks (
    eligibility_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id UUID NOT NULL REFERENCES crm_billing_insurance.patient_insurance_policies(policy_id),
    check_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(32) NOT NULL, -- 'ACTIVE_ELIGIBLE', 'INACTIVE', 'REJECTED'
    response_trace_number VARCHAR(64) NOT NULL,
    raw_271_response_json JSONB,
    verified_by VARCHAR(128) NOT NULL
);

-- Table 227: Medical & Vision Billing Invoices
CREATE TABLE IF NOT EXISTS crm_billing_insurance.invoices (
    invoice_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number VARCHAR(64) UNIQUE NOT NULL,
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    encounter_id UUID REFERENCES clinical.encounters(encounter_id),
    facility_id UUID NOT NULL REFERENCES core.clinical_facilities(facility_id),
    invoice_date DATE NOT NULL,
    due_date DATE NOT NULL,
    
    total_gross_amount NUMERIC(10,2) NOT NULL,
    insurance_expected_amount NUMERIC(10,2) DEFAULT 0.00 NOT NULL,
    insurance_paid_amount NUMERIC(10,2) DEFAULT 0.00 NOT NULL,
    patient_responsibility_amount NUMERIC(10,2) NOT NULL,
    patient_paid_amount NUMERIC(10,2) DEFAULT 0.00 NOT NULL,
    adjustment_amount NUMERIC(10,2) DEFAULT 0.00 NOT NULL,
    outstanding_balance NUMERIC(10,2) NOT NULL,
    
    payment_status VARCHAR(32) DEFAULT 'OPEN' NOT NULL, -- 'OPEN', 'PAID_IN_FULL', 'COLLECTIONS', 'WRITTEN_OFF'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    row_version INTEGER DEFAULT 1 NOT NULL
);

-- Table 228: Invoice Line Items
CREATE TABLE IF NOT EXISTS crm_billing_insurance.invoice_line_items (
    line_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES crm_billing_insurance.invoices(invoice_id) ON DELETE CASCADE,
    cpt_or_sku_code VARCHAR(32) NOT NULL,
    item_description VARCHAR(256) NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    quantity INTEGER DEFAULT 1 NOT NULL,
    line_total NUMERIC(10,2) NOT NULL,
    covered_by_insurance BOOLEAN DEFAULT TRUE
);

-- Table 229: Patient Payment Transactions (Credit Card, HSA/FSA, Cash)
CREATE TABLE IF NOT EXISTS crm_billing_insurance.payments (
    payment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES crm_billing_insurance.invoices(invoice_id),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    payment_method VARCHAR(32) NOT NULL, -- 'CREDIT_CARD', 'HSA_FSA', 'CASH', 'CHECK', 'FINANCING_CARECREDIT'
    payment_amount NUMERIC(10,2) NOT NULL,
    payment_gateway_txn_id VARCHAR(128),
    authorization_code VARCHAR(64),
    payment_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status VARCHAR(32) DEFAULT 'SUCCESS' NOT NULL
);

-- Table 230: EDI 837 Insurance Claims
CREATE TABLE IF NOT EXISTS crm_billing_insurance.insurance_claims (
    claim_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_number VARCHAR(64) UNIQUE NOT NULL,
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    payer_id UUID NOT NULL REFERENCES crm_billing_insurance.insurance_payers(payer_id),
    billing_provider_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    total_claim_charge_amount NUMERIC(10,2) NOT NULL,
    claim_filing_type VARCHAR(32) DEFAULT 'ELECTRONIC_837P',
    claim_status VARCHAR(32) DEFAULT 'ADJUDICATED' NOT NULL, -- 'QUEUED', 'SUBMITTED', 'ACCEPTED', 'DENIED', 'PAID'
    submission_date DATE NOT NULL,
    adjudication_date DATE,
    paid_amount NUMERIC(10,2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 231 to 270: Claims Adjudication, Denial Management, 835 ERA Payments
CREATE TABLE IF NOT EXISTS crm_billing_insurance.claim_line_details (
    claim_line_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_id UUID NOT NULL REFERENCES crm_billing_insurance.insurance_claims(claim_id) ON DELETE CASCADE,
    line_number INTEGER NOT NULL,
    procedure_code VARCHAR(10) NOT NULL,
    modifier_1 VARCHAR(4),
    modifier_2 VARCHAR(4),
    charge_amount NUMERIC(10,2) NOT NULL,
    allowed_amount NUMERIC(10,2),
    paid_amount NUMERIC(10,2) DEFAULT 0.00,
    coinsurance_amount NUMERIC(10,2) DEFAULT 0.00,
    deductible_amount NUMERIC(10,2) DEFAULT 0.00
);

CREATE TABLE IF NOT EXISTS crm_billing_insurance.claim_denials_log (
    denial_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_id UUID NOT NULL REFERENCES crm_billing_insurance.insurance_claims(claim_id),
    denial_reason_code VARCHAR(32) NOT NULL, -- e.g. 'CO-16', 'PR-96', 'CO-50'
    denial_reason_message TEXT NOT NULL,
    appeal_deadline DATE,
    appeal_status VARCHAR(32) DEFAULT 'UNDER_REVIEW',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Indices for crm & billing
CREATE INDEX IF NOT EXISTS idx_sf_accounts_type ON crm_billing_insurance.sf_accounts(account_type);
CREATE INDEX IF NOT EXISTS idx_policies_patient ON crm_billing_insurance.patient_insurance_policies(patient_id);
CREATE INDEX IF NOT EXISTS idx_invoices_patient ON crm_billing_insurance.invoices(patient_id);
CREATE INDEX IF NOT EXISTS idx_claims_patient ON crm_billing_insurance.insurance_claims(patient_id);
CREATE INDEX IF NOT EXISTS idx_claims_status ON crm_billing_insurance.insurance_claims(claim_status);
