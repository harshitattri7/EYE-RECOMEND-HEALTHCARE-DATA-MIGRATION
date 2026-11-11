"""
Synthetic Healthcare Data Generator for Eye Recommend Migration
Generates realistic patient profiles, clinical encounters, ophthalmic refractions,
and Salesforce CRM objects for local end-to-end testing and demonstration.
"""
import os
import sys
import json
import random
import argparse
from datetime import datetime, timedelta

FIRST_NAMES = ["James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda", "William", "Elizabeth", "David", "Barbara", "Richard", "Susan", "Joseph", "Jessica", "Thomas", "Sarah", "Charles", "Karen"]
LAST_NAMES = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin"]
CITIES = [("Austin", "TX", "78701"), ("Seattle", "WA", "98101"), ("Miami", "FL", "33139"), ("Chicago", "IL", "60601"), ("Denver", "CO", "80202"), ("Boston", "MA", "02108")]
CHIEF_COMPLAINTS = [
    "Blurry distance vision and intermittent headaches",
    "Annual routine comprehensive eye exam",
    "Dry, scratchy eyes when working on digital screens",
    "Contact lens check; slight redness in right eye",
    "Difficulty reading fine print in low light conditions",
    "Follow-up intraocular pressure check for glaucoma suspect",
    "Noticed sudden onset of floaters in peripheral vision"
]
PROVIDERS = [
    ("1982736450", "Dr. Sarah", "Chen", "OPTOMETRY"),
    ("1192837465", "Dr. Marcus", "Vance", "OPHTHALMOLOGY"),
    ("1827364519", "Dr. Elena", "Rostova", "RETINA_SPECIALIST")
]

def generate_patients(count: int = 1000):
    patients = []
    for i in range(1, count + 1):
        fn = random.choice(FIRST_NAMES)
        ln = random.choice(LAST_NAMES)
        city, state, zip_code = random.choice(CITIES)
        dob_year = random.randint(1945, 2012)
        dob_month = random.randint(1, 12)
        dob_day = random.randint(1, 28)
        dob = f"{dob_year:04d}-{dob_month:02d}-{dob_day:02d}"
        mrn = f"MRN-EYE-{10000 + i}"
        ssn = f"{random.randint(100,999)}-{random.randint(10,99)}-{random.randint(1000,9999)}"
        phone = f"555-{random.randint(100,999):03d}-{random.randint(1000,9999):04d}"
        email = f"{fn.lower()}.{ln.lower()}{i}@example.com"
        gender = random.choice(["MALE", "FEMALE"])

        patients.append({
            "nid": 1000 + i,
            "field_mrn_value": mrn,
            "field_first_name_value": fn,
            "field_last_name_value": ln,
            "field_dob_value": dob,
            "field_gender_value": gender,
            "field_ssn_value": ssn,
            "field_phone_value": phone,
            "field_email_value": email,
            "field_address_value": f"{random.randint(100, 9999)} Oak Street",
            "field_city_value": city,
            "field_state_value": state,
            "field_postal_code_value": zip_code,
            "created": 1609459200 + (i * 3600),
            "changed": 1672531199 + (i * 1800)
        })
    return patients

def generate_encounters_and_refractions(patients):
    encounters = []
    refractions = []
    encounter_id = 5000

    for p in patients:
        encounter_id += 1
        provider = random.choice(PROVIDERS)
        exam_date = datetime(2023, 1, 1) + timedelta(days=random.randint(1, 350), hours=random.randint(8, 17))
        
        encounters.append({
            "nid": encounter_id,
            "patient_nid": p["nid"],
            "provider_npi": provider[0],
            "encounter_date": exam_date.strftime("%Y-%m-%d %H:%M:%S"),
            "encounter_type": "COMPREHENSIVE_EYE_EXAM",
            "chief_complaint": random.choice(CHIEF_COMPLAINTS),
            "created": int(exam_date.timestamp()),
            "changed": int(exam_date.timestamp())
        })

        # Refraction parameters
        od_sph = round(random.uniform(-6.00, +4.00) * 4) / 4.0 # Quarter-diopter steps
        os_sph = round((od_sph + random.uniform(-0.75, +0.75)) * 4) / 4.0
        od_cyl = round(random.choice([0.0, -0.5, -0.75, -1.25, -1.75]), 2)
        os_cyl = round(random.choice([0.0, -0.5, -0.75, -1.25, -1.75]), 2)
        od_axis = random.randint(1, 180) if od_cyl != 0.0 else 180
        os_axis = random.randint(1, 180) if os_cyl != 0.0 else 180
        add_power = round(random.choice([None, 1.25, 1.75, 2.00, 2.50]), 2) if int(p["field_dob_value"][:4]) <= 1980 else None

        refractions.append({
            "encounter_nid": encounter_id,
            "patient_nid": p["nid"],
            "od_sphere": od_sph,
            "od_cylinder": od_cyl,
            "od_axis": od_axis,
            "od_add": add_power,
            "os_sphere": os_sph,
            "os_cylinder": os_cyl,
            "os_axis": os_axis,
            "os_add": add_power,
            "pd_binocular": round(random.uniform(59.0, 68.0), 1),
            "iop_od": round(random.uniform(11.0, 21.5), 1),
            "iop_os": round(random.uniform(11.0, 21.5), 1),
            "exam_timestamp": exam_date.strftime("%Y-%m-%d %H:%M:%S")
        })

    return encounters, refractions

def main():
    parser = argparse.ArgumentParser(description="Generate synthetic healthcare data")
    parser.add_argument("--records", type=int, default=1000, help="Number of patient records")
    parser.add_argument("--output", type=str, default="data/synthetic", help="Output directory")
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)
    print(f"Generating {args.records} synthetic patient clinical ecosystems...")

    patients = generate_patients(args.records)
    encounters, refractions = generate_encounters_and_refractions(patients)

    with open(os.path.join(args.output, "patients.json"), "w") as f:
        json.dump(patients, f, indent=2)
    with open(os.path.join(args.output, "encounters.json"), "w") as f:
        json.dump(encounters, f, indent=2)
    with open(os.path.join(args.output, "refractions.json"), "w") as f:
        json.dump(refractions, f, indent=2)

    print(f"Successfully generated:")
    print(f" - {len(patients)} Patients -> {os.path.join(args.output, 'patients.json')}")
    print(f" - {len(encounters)} Encounters -> {os.path.join(args.output, 'encounters.json')}")
    print(f" - {len(refractions)} Refraction Exams -> {os.path.join(args.output, 'refractions.json')}")

if __name__ == "__main__":
    main()
