-- ============================================================================
-- SCHEMA: optometry_ophthalmology (Eye Care, Refraction, Optical Orders & Exams)
-- Domain Group: 45 Production Tables ("Eye Recommend" Core Clinical Ecosystem)
-- ============================================================================

-- Table 176: Visual Acuity Measurements (OD, OS, OU)
CREATE TABLE IF NOT EXISTS optometry_ophthalmology.visual_acuity_exams (
    va_exam_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    
    -- Distance Vision Uncorrected (OD / OS / OU)
    distance_ucva_od VARCHAR(16), -- e.g. '20/40'
    distance_ucva_os VARCHAR(16),
    distance_ucva_ou VARCHAR(16),
    
    -- Distance Vision Best Corrected (OD / OS / OU)
    distance_bcva_od VARCHAR(16) NOT NULL, -- e.g. '20/20'
    distance_bcva_os VARCHAR(16) NOT NULL,
    distance_bcva_ou VARCHAR(16),
    
    -- Pinhole Acuity (OD / OS)
    pinhole_va_od VARCHAR(16),
    pinhole_va_os VARCHAR(16),
    
    -- Near Vision (OD / OS / OU)
    near_va_od VARCHAR(16), -- e.g. 'J1+' or '20/20'
    near_va_os VARCHAR(16),
    near_va_ou VARCHAR(16),
    
    testing_chart_type VARCHAR(32) DEFAULT 'SNELLEN', -- 'SNELLEN', 'ETDRS', 'LOGMAR'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 177: Comprehensive Refraction Examination (Manifest & Cycloplegic)
CREATE TABLE IF NOT EXISTS optometry_ophthalmology.refractions (
    refraction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    refraction_type VARCHAR(32) NOT NULL, -- 'MANIFEST', 'CYCLOPLEGIC', 'AUTOREFRACTION', 'HABITUAL'
    
    -- Right Eye (OD - Oculus Dexter)
    od_sphere NUMERIC(4,2) NOT NULL,    -- -20.00 to +20.00 diopters
    od_cylinder NUMERIC(4,2) DEFAULT 0.00 NOT NULL,  -- typically minus cylinder
    od_axis INTEGER CHECK (od_axis BETWEEN 1 AND 180),
    od_add NUMERIC(3,2),                 -- e.g. +1.50, +2.00, +2.50
    od_prism_value NUMERIC(4,2),
    od_prism_base VARCHAR(16),           -- 'UP', 'DOWN', 'IN', 'OUT'
    
    -- Left Eye (OS - Oculus Sinister)
    os_sphere NUMERIC(4,2) NOT NULL,
    os_cylinder NUMERIC(4,2) DEFAULT 0.00 NOT NULL,
    os_axis INTEGER CHECK (os_axis BETWEEN 1 AND 180),
    os_add NUMERIC(3,2),
    os_prism_value NUMERIC(4,2),
    os_prism_base VARCHAR(16),
    
    -- Pupillary Distance (PD)
    pupillary_distance_binocular NUMERIC(4,1), -- e.g. 64.0 mm
    pupillary_distance_monocular_od NUMERIC(4,1),
    pupillary_distance_monocular_os NUMERIC(4,1),
    
    is_final_prescribed BOOLEAN DEFAULT TRUE NOT NULL,
    refracted_by_practitioner_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 178: Tonometry & Intraocular Pressure (IOP) Glaucoma Screening
CREATE TABLE IF NOT EXISTS optometry_ophthalmology.tonometry_exams (
    tonometry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
    method VARCHAR(32) NOT NULL, -- 'GOLDMANN_APPLANATION', 'TONOPEN', 'ICARE_REBOUND', 'NCT_AIRPUFF'
    time_measured TIME NOT NULL,
    iop_od_mmhg NUMERIC(4,1) NOT NULL, -- e.g. 15.0 mmHg
    iop_os_mmhg NUMERIC(4,1) NOT NULL,
    corneal_pachymetry_od_microns INTEGER, -- central corneal thickness
    corneal_pachymetry_os_microns INTEGER,
    is_elevated BOOLEAN GENERATED ALWAYS AS (iop_od_mmhg > 21.0 OR iop_os_mmhg > 21.0) STORED,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 179: Slit Lamp Anterior Segment Examination
CREATE TABLE IF NOT EXISTS optometry_ophthalmology.slit_lamp_exams (
    slit_lamp_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
    
    -- Cornea
    cornea_od VARCHAR(128) DEFAULT 'Clear, smooth',
    cornea_os VARCHAR(128) DEFAULT 'Clear, smooth',
    
    -- Anterior Chamber
    anterior_chamber_od VARCHAR(128) DEFAULT 'Deep and quiet, Van Herick Grade 4',
    anterior_chamber_os VARCHAR(128) DEFAULT 'Deep and quiet, Van Herick Grade 4',
    
    -- Iris
    iris_od VARCHAR(128) DEFAULT 'Flat, normal architecture',
    iris_os VARCHAR(128) DEFAULT 'Flat, normal architecture',
    
    -- Crystalline Lens
    lens_od VARCHAR(128) DEFAULT 'Clear, no cataracts', -- or '1+ Nuclear Sclerosis'
    lens_os VARCHAR(128) DEFAULT 'Clear, no cataracts',
    
    -- Eyelids / Adnexa
    lids_lashes_od VARCHAR(128) DEFAULT 'Normal, no blepharitis',
    lids_lashes_os VARCHAR(128) DEFAULT 'Normal, no blepharitis',
    
    examining_practitioner_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 180: Dilated Fundus & Retinal Examination
CREATE TABLE IF NOT EXISTS optometry_ophthalmology.dilated_fundus_exams (
    fundus_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
    
    -- Optic Nerve & Cup-to-Disc Ratio (CDR)
    cup_to_disc_ratio_od NUMERIC(3,2) NOT NULL, -- e.g. 0.30
    cup_to_disc_ratio_os NUMERIC(3,2) NOT NULL,
    optic_disc_margin_od VARCHAR(64) DEFAULT 'Sharp, pink, well-perfused',
    optic_disc_margin_os VARCHAR(64) DEFAULT 'Sharp, pink, well-perfused',
    
    -- Macula
    macula_od VARCHAR(128) DEFAULT 'Flat, positive foveal reflex, no drusen',
    macula_os VARCHAR(128) DEFAULT 'Flat, positive foveal reflex, no drusen',
    
    -- Retinal Vessels & Periphery
    retinal_vessels_od VARCHAR(128) DEFAULT 'Normal caliber, A/V ratio 2/3',
    retinal_vessels_os VARCHAR(128) DEFAULT 'Normal caliber, A/V ratio 2/3',
    periphery_od VARCHAR(128) DEFAULT '360 degrees flat and intact, no tears',
    periphery_os VARCHAR(128) DEFAULT '360 degrees flat and intact, no tears',
    
    dilation_agent_used VARCHAR(64) DEFAULT 'Tropicamide 1% + Phenylephrine 2.5%',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 181: Optical Eyewear Prescriptions (Specs)
CREATE TABLE IF NOT EXISTS optometry_ophthalmology.eyewear_prescriptions (
    prescription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    prescriber_id UUID NOT NULL REFERENCES core.practitioners(practitioner_id),
    refraction_id UUID NOT NULL REFERENCES optometry_ophthalmology.refractions(refraction_id),
    
    lens_type VARCHAR(64) NOT NULL, -- 'SINGLE_VISION', 'PROGRESSIVE_PAL', 'BIFOCAL_FT28', 'TRIFOCAL'
    material_recommended VARCHAR(64) DEFAULT 'POLYCARBONATE', -- 'CR39_PLASTIC', 'POLYCARBONATE', 'HI_INDEX_167', 'TRIVEX'
    anti_reflective_coating BOOLEAN DEFAULT TRUE,
    blue_light_filter BOOLEAN DEFAULT TRUE,
    photochromic_transitions BOOLEAN DEFAULT FALSE,
    polarized BOOLEAN DEFAULT FALSE,
    
    issued_date DATE NOT NULL,
    expiration_date DATE NOT NULL, -- typically 1 or 2 years in optometry
    special_usage_notes TEXT, -- 'Computer distance / office ergonomics'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 182: Contact Lens Fittings & Parameters
CREATE TABLE IF NOT EXISTS optometry_ophthalmology.contact_lens_prescriptions (
    cl_rx_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    lens_brand VARCHAR(128) NOT NULL, -- 'Acuvue Oasys', 'Dailies Total 1', 'Biofinity Toric'
    manufacturer VARCHAR(128) NOT NULL,
    replacement_schedule VARCHAR(32) NOT NULL, -- 'DAILY_DISPOSABLE', 'BI_WEEKLY', 'MONTHLY'
    
    -- OD Specs
    od_base_curve NUMERIC(4,2) NOT NULL, -- e.g. 8.5 mm
    od_diameter NUMERIC(4,1) NOT NULL,   -- e.g. 14.2 mm
    od_power NUMERIC(4,2) NOT NULL,      -- sphere power
    od_cylinder NUMERIC(4,2),            -- toric cylinder
    od_axis INTEGER,
    od_add_power VARCHAR(16),            -- multifocal ADD (LOW, MED, HIGH)
    
    -- OS Specs
    os_base_curve NUMERIC(4,2) NOT NULL,
    os_diameter NUMERIC(4,1) NOT NULL,
    os_power NUMERIC(4,2) NOT NULL,
    os_cylinder NUMERIC(4,2),
    os_axis INTEGER,
    os_add_power VARCHAR(16),
    
    fit_assessment VARCHAR(32) DEFAULT 'OPTIMAL_CENTRAL_MOVEMENT',
    issued_date DATE NOT NULL,
    expiration_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Table 183: Optical Eyewear Retail & Dispensary Orders
CREATE TABLE IF NOT EXISTS optometry_ophthalmology.optical_dispensary_orders (
    order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES core.patients(patient_id),
    prescription_id UUID NOT NULL REFERENCES optometry_ophthalmology.eyewear_prescriptions(prescription_id),
    facility_id UUID NOT NULL REFERENCES core.clinical_facilities(facility_id),
    dispensing_optician_name VARCHAR(128) NOT NULL,
    
    frame_sku VARCHAR(64) NOT NULL,
    frame_brand VARCHAR(128) NOT NULL, -- 'Ray-Ban', 'Gucci', 'Oakley', 'Silhouette'
    frame_model VARCHAR(128) NOT NULL,
    frame_color VARCHAR(64) NOT NULL,
    frame_size_eye_bridge_temple VARCHAR(32) NOT NULL, -- '52-18-140'
    
    optical_lab_name VARCHAR(128) NOT NULL, -- 'Essilor Expert Lab', 'Hoya Vision Care'
    lab_work_order_number VARCHAR(64) UNIQUE,
    order_status VARCHAR(32) DEFAULT 'ORDER_TRANSMITTED', -- 'ORDER_TRANSMITTED', 'SURFACING', 'EDGING', 'QC_INSPECTION', 'READY_FOR_DISPENSE', 'DISPENSED'
    
    retail_total_amount NUMERIC(10,2) NOT NULL,
    insurance_coverage_amount NUMERIC(10,2) DEFAULT 0.00,
    patient_responsibility_amount NUMERIC(10,2) NOT NULL,
    
    order_placed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    dispensed_at TIMESTAMP WITH TIME ZONE,
    warranty_expiration_date DATE
);

-- Table 184 to 220: Keratometry, Corneal Topography, Dry Eye TBUT, Optical Frames Inventory
CREATE TABLE IF NOT EXISTS optometry_ophthalmology.keratometry_readings (
    keratometry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    od_k1 NUMERIC(4,2) NOT NULL, -- flat K
    od_k2 NUMERIC(4,2) NOT NULL, -- steep K
    od_k_axis INTEGER NOT NULL,
    os_k1 NUMERIC(4,2) NOT NULL,
    os_k2 NUMERIC(4,2) NOT NULL,
    os_k_axis INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS optometry_ophthalmology.dry_eye_evaluations (
    dry_eye_eval_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
    tear_breakup_time_seconds_od INTEGER, -- TBUT (<10s is abnormal)
    tear_breakup_time_seconds_os INTEGER,
    schirmer_test_mm_od INTEGER,          -- Tear volume
    schirmer_test_mm_os INTEGER,
    corneal_staining_scale VARCHAR(32),   -- 'NONE', 'MILD_PUNCTATE', 'CONFLUENT'
    meibomian_gland_dysfunction_grade INTEGER CHECK (meibomian_gland_dysfunction_grade BETWEEN 0 AND 4),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE IF NOT EXISTS optometry_ophthalmology.catalog_frames_inventory (
    frame_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku VARCHAR(64) UNIQUE NOT NULL,
    brand VARCHAR(128) NOT NULL,
    collection VARCHAR(128),
    frame_type VARCHAR(64) NOT NULL, -- 'FULL_RIM', 'SEMI_RIMLESS', 'RIMLESS'
    material VARCHAR(64) NOT NULL,   -- 'TITANIUM', 'ACETATE', 'STAINLESS_STEEL'
    gender_target VARCHAR(24),       -- 'UNISEX', 'MEN', 'WOMEN', 'KIDS'
    wholesale_cost NUMERIC(8,2) NOT NULL,
    retail_price NUMERIC(8,2) NOT NULL,
    stock_quantity INTEGER DEFAULT 0 NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL
);

-- Indices for optometry schema
CREATE INDEX IF NOT EXISTS idx_va_encounter ON optometry_ophthalmology.visual_acuity_exams(encounter_id);
CREATE INDEX IF NOT EXISTS idx_refractions_patient ON optometry_ophthalmology.refractions(patient_id);
CREATE INDEX IF NOT EXISTS idx_tonometry_encounter ON optometry_ophthalmology.tonometry_exams(encounter_id);
CREATE INDEX IF NOT EXISTS idx_eyewear_rx_patient ON optometry_ophthalmology.eyewear_prescriptions(patient_id);
CREATE INDEX IF NOT EXISTS idx_optical_orders_status ON optometry_ophthalmology.optical_dispensary_orders(order_status);
