-- ============================================================================
-- LEGACY SOURCE: Drupal MariaDB Healthcare System (drupal_eyerecommend_ehr)
-- ============================================================================

CREATE DATABASE IF NOT EXISTS drupal_eyerecommend_ehr;
USE drupal_eyerecommend_ehr;

-- Drupal legacy node table for patients
CREATE TABLE IF NOT EXISTS node_patient_profile (
    nid INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    vid INT UNSIGNED NOT NULL,
    type VARCHAR(32) NOT NULL DEFAULT 'patient_profile',
    title VARCHAR(255) NOT NULL,
    uid INT NOT NULL DEFAULT 1,
    status INT NOT NULL DEFAULT 1,
    created INT NOT NULL,
    changed INT NOT NULL
);

-- Drupal field data for patient demographics
CREATE TABLE IF NOT EXISTS field_data_patient_demographics (
    entity_type VARCHAR(128) NOT NULL DEFAULT 'node',
    bundle VARCHAR(128) NOT NULL DEFAULT 'patient_profile',
    deleted TINYINT NOT NULL DEFAULT 0,
    entity_id INT UNSIGNED NOT NULL,
    revision_id INT UNSIGNED NOT NULL,
    language VARCHAR(12) NOT NULL DEFAULT 'und',
    delta INT UNSIGNED NOT NULL DEFAULT 0,
    field_mrn_value VARCHAR(64) NOT NULL,
    field_first_name_value VARCHAR(64) NOT NULL,
    field_last_name_value VARCHAR(64) NOT NULL,
    field_dob_value DATE NOT NULL,
    field_gender_value VARCHAR(16) NOT NULL,
    field_ssn_value VARCHAR(16),
    field_phone_value VARCHAR(32),
    field_email_value VARCHAR(128),
    field_address_value VARCHAR(255),
    field_city_value VARCHAR(64),
    field_state_value VARCHAR(32),
    field_postal_code_value VARCHAR(16),
    PRIMARY KEY (entity_id, deleted, delta),
    KEY (field_mrn_value)
);

-- Drupal encounter table
CREATE TABLE IF NOT EXISTS node_clinical_encounter (
    nid INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    vid INT UNSIGNED NOT NULL,
    type VARCHAR(32) NOT NULL DEFAULT 'clinical_encounter',
    title VARCHAR(255) NOT NULL,
    created INT NOT NULL,
    changed INT NOT NULL,
    patient_nid INT UNSIGNED NOT NULL,
    provider_npi VARCHAR(10) NOT NULL,
    encounter_date DATETIME NOT NULL,
    encounter_type VARCHAR(64) NOT NULL,
    chief_complaint TEXT
);

-- Drupal refraction examination data
CREATE TABLE IF NOT EXISTS field_data_refraction (
    encounter_nid INT UNSIGNED NOT NULL PRIMARY KEY,
    od_sphere DECIMAL(4,2) NOT NULL,
    od_cylinder DECIMAL(4,2) NOT NULL DEFAULT 0.00,
    od_axis INT NOT NULL,
    od_add DECIMAL(3,2),
    os_sphere DECIMAL(4,2) NOT NULL,
    os_cylinder DECIMAL(4,2) NOT NULL DEFAULT 0.00,
    os_axis INT NOT NULL,
    os_add DECIMAL(3,2),
    pd_binocular DECIMAL(4,1),
    iop_od DECIMAL(4,1),
    iop_os DECIMAL(4,1),
    exam_timestamp DATETIME NOT NULL
);

-- Seed initial legacy records
INSERT INTO node_patient_profile (nid, vid, title, created, changed) VALUES
(1001, 1001, 'John Doe', 1609459200, 1672531199),
(1002, 1002, 'Jane Smith', 1612137600, 1672531199),
(1003, 1003, 'Robert Johnson', 1614556800, 1672531199);

INSERT INTO field_data_patient_demographics 
(entity_id, revision_id, field_mrn_value, field_first_name_value, field_last_name_value, field_dob_value, field_gender_value, field_ssn_value, field_phone_value, field_email_value, field_address_value, field_city_value, field_state_value, field_postal_code_value) 
VALUES
(1001, 1001, 'MRN-EYE-10001', 'John', 'Doe', '1982-04-12', 'MALE', '987-65-4321', '555-019-2831', 'johndoe@email.com', '124 Maple St', 'Austin', 'TX', '78701'),
(1002, 1002, 'MRN-EYE-10002', 'Jane', 'Smith', '1990-09-24', 'FEMALE', '987-65-8842', '555-019-9943', 'janesmith@email.com', '742 Evergreen Terr', 'Seattle', 'WA', '98101'),
(1003, 1003, 'MRN-EYE-10003', 'Robert', 'Johnson', '1975-11-03', 'MALE', '987-65-1123', '555-019-3321', 'rjohnson@email.com', '45 Ocean Dr', 'Miami', 'FL', '33139');

INSERT INTO node_clinical_encounter 
(nid, vid, title, created, changed, patient_nid, provider_npi, encounter_date, encounter_type, chief_complaint)
VALUES
(5001, 5001, 'Exam 5001', 1672600000, 1672600000, 1001, '1982736450', '2023-01-02 09:30:00', 'COMPREHENSIVE_EYE_EXAM', 'Blurry distance vision and eye strain while reading'),
(5002, 5002, 'Exam 5002', 1672700000, 1672700000, 1002, '1982736450', '2023-01-03 14:00:00', 'CONTACT_LENS_FIT', 'Annual contact lens renewal; dry eyes in afternoons'),
(5003, 5003, 'Exam 5003', 1672800000, 1672800000, 1003, '1192837465', '2023-01-04 11:15:00', 'GLAUCOMA_WORKUP', 'Family history of glaucoma; routine pressure check');

INSERT INTO field_data_refraction
(encounter_nid, od_sphere, od_cylinder, od_axis, od_add, os_sphere, os_cylinder, os_axis, os_add, pd_binocular, iop_od, iop_os, exam_timestamp)
VALUES
(5001, -2.50, -0.75, 95, 1.75, -2.75, -0.50, 85, 1.75, 63.5, 14.5, 15.0, '2023-01-02 09:45:00'),
(5002, -1.75, 0.00, 180, NULL, -1.50, -0.25, 175, NULL, 61.0, 16.0, 16.5, '2023-01-03 14:20:00'),
(5003, +0.50, -0.50, 10, 2.25, +0.75, -0.75, 170, 2.25, 64.0, 22.5, 23.0, '2023-01-04 11:35:00');
