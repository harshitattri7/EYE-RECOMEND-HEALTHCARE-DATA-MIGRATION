"""
Synthetic Healthcare Data Generator for Eye Recommend Migration
Generates realistic patient profiles, clinical encounters, ophthalmic refractions,
and Salesforce CRM objects for local end-to-end testing and demonstration.

Realism features:
  - Age drawn from a Gaussian distribution (mean=55, sd=18, clipped 0-95)
  - Sphere drawn from a bimodal distribution (70% myopia, 25% hyperopia, 5% outlier)
  - IOP drawn from a right-skewed log-normal distribution
  - Email/phone have realistic null and malformed rates
  - Cylinder is None for ~30% of patients (emmetropia / no recorded astigmatism)
  - ~2% of records are duplicate candidates with slight name/phone typos
  - Encounter timestamps are business-hour weighted (Mon-Fri, 09:00-16:00, 2023)
"""

import os
import json
import math
import random
import argparse
import statistics
from datetime import datetime, timedelta, date

# ---------------------------------------------------------------------------
# Reference tables
# ---------------------------------------------------------------------------
FIRST_NAMES = [
    "James", "Mary", "John", "Patricia", "Robert", "Jennifer",
    "Michael", "Linda", "William", "Elizabeth", "David", "Barbara",
    "Richard", "Susan", "Joseph", "Jessica", "Thomas", "Sarah",
    "Charles", "Karen", "Nancy", "Lisa", "Betty", "Margaret",
    "Dorothy", "Sandra", "Ashley", "Dorothy", "Kimberly", "Emily",
]
LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia",
    "Miller", "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez",
    "Gonzalez", "Wilson", "Anderson", "Thomas", "Taylor", "Moore",
    "Jackson", "Martin", "Lee", "Perez", "Thompson", "White", "Harris",
]
# Weighted by realistic clinic catchment: nearby cities dominate
CITIES_WEIGHTS = [
    (("Austin",    "TX", "78701"), 0.38),
    (("Round Rock","TX", "78681"), 0.22),
    (("Cedar Park","TX", "78613"), 0.14),
    (("Seattle",   "WA", "98101"), 0.10),
    (("Miami",     "FL", "33139"), 0.08),
    (("Chicago",   "IL", "60601"), 0.05),
    (("Denver",    "CO", "80202"), 0.03),
]
CHIEF_COMPLAINTS = [
    "Blurry distance vision and intermittent headaches",
    "Annual routine comprehensive eye exam",
    "Dry, scratchy eyes when working on digital screens",
    "Contact lens check; slight redness in right eye",
    "Difficulty reading fine print in low light conditions",
    "Follow-up intraocular pressure check for glaucoma suspect",
    "Noticed sudden onset of floaters in peripheral vision",
    "Eye strain after prolonged computer use",
    "Glasses prescription update needed",
    "Post-cataract surgery follow-up",
]
PROVIDERS = [
    ("1982736450", "Dr. Sarah",  "Chen",    "OPTOMETRY"),
    ("1192837465", "Dr. Marcus", "Vance",   "OPHTHALMOLOGY"),
    ("1827364519", "Dr. Elena",  "Rostova", "RETINA_SPECIALIST"),
    ("1736458291", "Dr. Ajay",   "Kapoor",  "OPTOMETRY"),
]
STREET_TYPES  = ["Oak St", "Maple Ave", "Cedar Blvd", "Elm Dr", "Pine Rd",
                 "Birch Ln", "Spruce Ct", "Walnut Way", "Willow Pl"]
PHONE_FORMATS = [
    lambda a, b: f"{a}-{b}",          # 555-123-4567
    lambda a, b: f"({a[:3]}) {a[3:]}-{b}",  # (555) 123-4567
    lambda a, b: f"{a}{b}",           # 5551234567
    lambda a, b: f"{a}.{b}",          # 555.123.4567
]

# ---------------------------------------------------------------------------
# Distribution helpers
# ---------------------------------------------------------------------------

def _weighted_choice(weighted_items):
    """Pick from [(item, weight), ...] with normalised weights."""
    items, weights = zip(*weighted_items)
    return random.choices(items, weights=weights, k=1)[0]


def _gauss_int(mean: float, sd: float, lo: int, hi: int) -> int:
    """Sample an integer from a Gaussian, clipped to [lo, hi]."""
    return int(max(lo, min(hi, round(random.gauss(mean, sd)))))


def _bimodal_sphere() -> float:
    """
    Realistic refractive-error distribution:
      70% myopia  cluster ~ N(-1.2, 1.5)  clipped [-12, -0.25]
      25% hyperopia cluster ~ N(+1.5, 1.0) clipped [+0.25, +6.0]
       5% extreme outlier   uniform [-18, +8] (high myopia / high hyperopia)
    All rounded to nearest 0.25 D.
    """
    r = random.random()
    if r < 0.70:
        raw = random.gauss(-1.2, 1.5)
        raw = max(-12.0, min(-0.25, raw))
    elif r < 0.95:
        raw = random.gauss(1.5, 1.0)
        raw = max(0.25, min(6.0, raw))
    else:
        raw = random.uniform(-18.0, 8.0)
    return round(round(raw * 4) / 4.0, 2)   # quarter-diopter step


def _lognormal_iop() -> float:
    """
    IOP is right-skewed in the population (median ~14, tail toward 30+).
    Model with lognormal: mu=2.65, sigma=0.18 → median ≈ 14.1 mmHg.
    Clip to physiologically plausible range [8, 35].
    """
    raw = random.lognormvariate(2.65, 0.18)
    return round(max(8.0, min(35.0, raw)), 1)


def _business_timestamp(year: int = 2023) -> datetime:
    """
    Return a random datetime on a weekday in `year`, with hours
    weighted toward 09:00–16:00 (appointment-hour distribution).
    """
    # Pick a random day in 2023, skip weekends
    jan1 = date(year, 1, 1)
    for _ in range(500):                 # safety limit
        delta_days = random.randint(0, 364)
        d = jan1 + timedelta(days=delta_days)
        if d.weekday() < 5:              # Mon=0 … Fri=4
            break

    # Hour weighted toward mid-morning / early afternoon
    hour_weights = [0, 0, 0, 0, 0, 0, 0, 0, 0,  # 00-08
                    8, 10, 9, 7, 9, 10, 8, 4, 2,  # 09-17
                    1, 0, 0, 0, 0, 0]              # 18-23
    hour  = random.choices(range(24), weights=hour_weights, k=1)[0]
    minute = random.randint(0, 59)
    second = random.randint(0, 59)
    return datetime(d.year, d.month, d.day, hour, minute, second)


def _registration_timestamp(encounter_ts: datetime) -> datetime:
    """
    Patient registration precedes their first encounter by 1–730 days.
    If the computed day falls on a weekend, roll back to the nearest Friday.
    """
    offset_days = random.randint(1, 730)
    offset_secs = random.randint(0, 3600)
    reg_ts = encounter_ts - timedelta(days=offset_days, seconds=offset_secs)
    # Roll weekend back to Friday
    if reg_ts.weekday() == 5:   # Saturday → Friday
        reg_ts -= timedelta(days=1)
    elif reg_ts.weekday() == 6: # Sunday → Friday
        reg_ts -= timedelta(days=2)
    return reg_ts


def _maybe_messy_phone(raw_area: str, raw_num: str) -> str | None:
    """
    12% → None (not collected)
    88% → one of four mixed formats
    """
    if random.random() < 0.12:
        return None
    fmt = random.choice(PHONE_FORMATS)
    return fmt(raw_area + raw_num[:3], raw_num[3:])


def _maybe_messy_email(fn: str, ln: str, idx: int) -> str | None:
    """
    18% → None (not collected)
     4% → malformed (missing @, missing TLD, etc.)
    78% → clean lowercase email
    """
    r = random.random()
    if r < 0.18:
        return None
    if r < 0.22:                         # 4% malformed
        malformed_pool = [
            f"{fn.lower()}.{ln.lower()}{idx}@",           # no domain
            f"{fn.lower()}{ln.lower()}{idx}gmail.com",    # missing @
            f"{fn.lower()}@{ln.lower()}",                  # no TLD
            f"  {fn.lower()}.{ln.lower()}@example.com ",  # leading/trailing spaces
        ]
        return random.choice(malformed_pool)
    return f"{fn.lower()}.{ln.lower()}{idx}@example.com"


def _cylinder_and_axis() -> tuple:
    """
    ~30% of patients have zero cylinder (no astigmatism recorded → None).
    Remaining follow a realistic clinical distribution.
    Returns (cylinder, axis) — axis is None when cylinder is None.
    """
    if random.random() < 0.30:
        return None, None
    cyl_values = [(-0.25, 0.10), (-0.50, 0.25), (-0.75, 0.22),
                  (-1.00, 0.15), (-1.25, 0.12), (-1.50, 0.08),
                  (-1.75, 0.04), (-2.00, 0.03), (-2.50, 0.01)]
    cyls, cyl_wts = zip(*cyl_values)
    cyl  = random.choices(cyls, weights=cyl_wts, k=1)[0]
    axis = random.randint(1, 180)
    return cyl, axis


def _add_power(age: int) -> float | None:
    """
    Add power is prescribed for presbyopia (age ≥ 40 typically).
    - Age < 40 → None
    - Age 40-50 → mild add (1.00–1.50)
    - Age 51-60 → moderate (1.50–2.00)
    - Age 61+   → strong  (2.00–3.00)
    ~10% of qualifying patients still have None (not recorded).
    """
    if age < 40:
        return None
    if random.random() < 0.10:
        return None
    if age <= 50:
        raw = random.uniform(1.00, 1.50)
    elif age <= 60:
        raw = random.uniform(1.50, 2.00)
    else:
        raw = random.uniform(2.00, 3.00)
    return round(round(raw * 4) / 4.0, 2)   # quarter-diopter step


# ---------------------------------------------------------------------------
# Record generators
# ---------------------------------------------------------------------------

def _dob_from_age(age: int, reference_year: int = 2023) -> str:
    """Convert an age (integer years) to a plausible YYYY-MM-DD birth date."""
    birth_year  = reference_year - age
    birth_month = random.randint(1, 12)
    birth_day   = random.randint(1, 28)
    return f"{birth_year:04d}-{birth_month:02d}-{birth_day:02d}"


def generate_patients(count: int = 1000):
    patients = []
    # Pre-select ~2% indices that will become duplicate candidates
    total_with_dupes = count
    base_count       = int(count * 0.98)
    dupe_source_idxs = random.sample(range(base_count), k=max(1, count - base_count))

    for i in range(1, base_count + 1):
        fn         = random.choice(FIRST_NAMES)
        ln         = random.choice(LAST_NAMES)
        city, state, zip_code = _weighted_choice(CITIES_WEIGHTS)
        age        = _gauss_int(55, 18, 5, 95)
        dob        = _dob_from_age(age)
        gender     = random.choices(["FEMALE", "MALE"], weights=[0.54, 0.46], k=1)[0]
        mrn        = f"MRN-EYE-{10000 + i}"
        area       = str(random.randint(200, 999))
        num        = f"{random.randint(2000000, 9999999):07d}"
        ssn_raw    = f"{random.randint(100,899)}-{random.randint(10,99)}-{random.randint(1000,9999)}"
        phone      = _maybe_messy_phone(area, num)
        email      = _maybe_messy_email(fn, ln, i)

        # Realistic business-hours registration timestamp
        enc_ts     = _business_timestamp(2023)
        reg_ts     = _registration_timestamp(enc_ts)

        patients.append({
            "nid":                    1000 + i,
            "field_mrn_value":        mrn,
            "field_first_name_value": fn,
            "field_last_name_value":  ln,
            "field_dob_value":        dob,
            "field_age_at_gen":       age,          # kept for verification; strip before prod load
            "field_gender_value":     gender,
            "field_ssn_value":        ssn_raw,
            "field_phone_value":      phone,
            "field_email_value":      email,
            "field_address_value":    f"{random.randint(100, 9999)} {random.choice(STREET_TYPES)}",
            "field_city_value":       city,
            "field_state_value":      state,
            "field_postal_code_value": zip_code,
            "created":                int(reg_ts.timestamp()),
            "changed":                int(enc_ts.timestamp()),
            "is_duplicate_candidate": False,
        })

    # ---- Inject duplicate candidates (~2%) --------------------------------
    for src_idx in dupe_source_idxs:
        original = patients[src_idx]
        dupe_i   = base_count + dupe_source_idxs.index(src_idx) + 1

        # Introduce realistic typos / format variation
        fn_dupe   = original["field_first_name_value"]
        ln_dupe   = original["field_last_name_value"]

        # Randomly corrupt one character in the last name (transposition typo)
        if len(ln_dupe) > 3:
            pos = random.randint(1, len(ln_dupe) - 2)
            ln_dupe = ln_dupe[:pos] + ln_dupe[pos+1] + ln_dupe[pos] + ln_dupe[pos+2:]

        # Phone in a different format or None
        area2 = str(random.randint(200, 999))
        num2  = f"{random.randint(2000000, 9999999):07d}"
        phone_dupe = _maybe_messy_phone(area2, num2) if random.random() > 0.3 else None

        dupe_ts = _business_timestamp(2023)
        patients.append({
            "nid":                    1000 + dupe_i + base_count,
            "field_mrn_value":        f"MRN-EYE-DUP-{10000 + dupe_i}",   # different MRN → why MPI matters
            "field_first_name_value": fn_dupe,
            "field_last_name_value":  ln_dupe,
            "field_dob_value":        original["field_dob_value"],         # same DOB → fuzzy-match clue
            "field_age_at_gen":       original["field_age_at_gen"],
            "field_gender_value":     original["field_gender_value"],
            "field_ssn_value":        original["field_ssn_value"],         # same SSN → deterministic link
            "field_phone_value":      phone_dupe,
            "field_email_value":      None,                                 # common: duplicate has no email
            "field_address_value":    original["field_address_value"],
            "field_city_value":       original["field_city_value"],
            "field_state_value":      original["field_state_value"],
            "field_postal_code_value": original["field_postal_code_value"],
            "created":                int(dupe_ts.timestamp()),
            "changed":                int(dupe_ts.timestamp()),
            "is_duplicate_candidate": True,
        })

    return patients


def generate_encounters_and_refractions(patients):
    encounters  = []
    refractions = []
    encounter_id = 5000

    for p in patients:
        encounter_id += 1
        provider   = random.choice(PROVIDERS)
        exam_ts    = _business_timestamp(2023)
        age        = p["field_age_at_gen"]

        encounters.append({
            "nid":            encounter_id,
            "patient_nid":    p["nid"],
            "provider_npi":   provider[0],
            "encounter_date": exam_ts.strftime("%Y-%m-%d %H:%M:%S"),
            "encounter_type": "COMPREHENSIVE_EYE_EXAM",
            "chief_complaint": random.choice(CHIEF_COMPLAINTS),
            "created":        int(exam_ts.timestamp()),
            "changed":        int(exam_ts.timestamp()),
        })

        # ---- Refraction ---------------------------------------------------
        od_sph       = _bimodal_sphere()
        # Fellow eye is correlated to dominant eye, not independent
        os_sph       = round(od_sph + random.gauss(0, 0.5), 2)
        os_sph       = round(round(os_sph * 4) / 4.0, 2)

        od_cyl, od_axis = _cylinder_and_axis()
        os_cyl, os_axis = _cylinder_and_axis()

        add = _add_power(age)   # None for age < 40 or not recorded; no round(None) risk

        # PD: normally distributed, mean 63 mm, sd 3 mm, clipped [54, 74]
        pd_bino = round(max(54.0, min(74.0, random.gauss(63.0, 3.0))), 1)

        # IOP: right-skewed log-normal
        iop_od = _lognormal_iop()
        iop_os = _lognormal_iop()

        refractions.append({
            "encounter_nid":  encounter_id,
            "patient_nid":    p["nid"],
            "od_sphere":      od_sph,
            "od_cylinder":    od_cyl,
            "od_axis":        od_axis,
            "od_add":         add,
            "os_sphere":      os_sph,
            "os_cylinder":    os_cyl,
            "os_axis":        os_axis,
            "os_add":         add,
            "pd_binocular":   pd_bino,
            "iop_od":         iop_od,
            "iop_os":         iop_os,
            "exam_timestamp": exam_ts.strftime("%Y-%m-%d %H:%M:%S"),
        })

    return encounters, refractions


# ---------------------------------------------------------------------------
# CLI entry-point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Generate realistic synthetic healthcare data")
    parser.add_argument("--records", type=int, default=1000,
                        help="Number of base patient records (before 2%% duplicate injection)")
    parser.add_argument("--output", type=str, default="data/synthetic",
                        help="Output directory")
    parser.add_argument("--seed",   type=int, default=None,
                        help="Random seed for reproducibility")
    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    os.makedirs(args.output, exist_ok=True)
    print(f"Generating {args.records} base patient records (+ ~2% duplicate candidates)…\n")

    patients              = generate_patients(args.records)
    encounters, refractions = generate_encounters_and_refractions(patients)

    with open(os.path.join(args.output, "patients.json"),    "w") as f:
        json.dump(patients,    f, indent=2)
    with open(os.path.join(args.output, "encounters.json"),  "w") as f:
        json.dump(encounters,  f, indent=2)
    with open(os.path.join(args.output, "refractions.json"), "w") as f:
        json.dump(refractions, f, indent=2)

    print(f"  Patients written  → {os.path.join(args.output, 'patients.json')}")
    print(f"  Encounters written → {os.path.join(args.output, 'encounters.json')}")
    print(f"  Refractions written → {os.path.join(args.output, 'refractions.json')}\n")


# ---------------------------------------------------------------------------
# Verification block — prints distribution stats when run directly
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys

    # Use seed=42 so the stats are reproducible for verification
    random.seed(42)
    N = 1000

    print("=" * 60)
    print(f"  VERIFICATION RUN — {N} base patients + ~2% dupes")
    print("=" * 60)

    patients = generate_patients(N)
    encounters, refractions = generate_encounters_and_refractions(patients)

    # ---- Age stats --------------------------------------------------------
    ages = [p["field_age_at_gen"] for p in patients if not p["is_duplicate_candidate"]]
    print(f"\n[Age distribution]  (Gaussian mean=55, sd=18, clipped 0-95)")
    print(f"  Count : {len(ages)}")
    print(f"  Min   : {min(ages)}")
    print(f"  Max   : {max(ages)}")
    print(f"  Mean  : {statistics.mean(ages):.1f}")
    print(f"  Stdev : {statistics.stdev(ages):.1f}")
    under40 = sum(1 for a in ages if a < 40)
    print(f"  < 40  : {under40}  ({100*under40/len(ages):.1f}%)")
    over60  = sum(1 for a in ages if a >= 60)
    print(f"  ≥ 60  : {over60}  ({100*over60/len(ages):.1f}%)")

    # ---- Email / phone null counts ----------------------------------------
    emails  = [p["field_email_value"]  for p in patients]
    phones  = [p["field_phone_value"]  for p in patients]
    null_emails   = sum(1 for e in emails if e is None)
    bad_emails    = sum(1 for e in emails if e and ("  " in e or e.endswith("@") or "gmail.com" in e and "@" not in e))
    null_phones   = sum(1 for ph in phones if ph is None)
    print(f"\n[Email quality]")
    print(f"  None (not collected) : {null_emails}  ({100*null_emails/len(emails):.1f}%)")
    print(f"  Malformed            : {bad_emails}  ({100*bad_emails/len(emails):.1f}%)")
    print(f"\n[Phone quality]")
    print(f"  None (not collected) : {null_phones}  ({100*null_phones/len(phones):.1f}%)")

    # ---- Duplicate candidates ---------------------------------------------
    dupes = [p for p in patients if p["is_duplicate_candidate"]]
    print(f"\n[Duplicate candidates injected] : {len(dupes)}  ({100*len(dupes)/len(patients):.1f}% of total)")

    # ---- Sphere distribution ----------------------------------------------
    od_spheres = [r["od_sphere"] for r in refractions]
    myopia     = sum(1 for s in od_spheres if s < 0)
    hyperopia  = sum(1 for s in od_spheres if s > 0)
    emmetropic = sum(1 for s in od_spheres if s == 0.0)
    print(f"\n[OD Sphere distribution]  (bimodal)")
    print(f"  Min      : {min(od_spheres):.2f} D")
    print(f"  Max      : {max(od_spheres):.2f} D")
    print(f"  Mean     : {statistics.mean(od_spheres):.2f} D")
    print(f"  Myopic   : {myopia}  ({100*myopia/len(od_spheres):.1f}%)")
    print(f"  Hyperopic: {hyperopia}  ({100*hyperopia/len(od_spheres):.1f}%)")
    print(f"  Plano    : {emmetropic}")

    # ---- Cylinder null rate -----------------------------------------------
    null_cyl = sum(1 for r in refractions if r["od_cylinder"] is None)
    print(f"\n[OD Cylinder]  (None = no astigmatism recorded)")
    print(f"  None : {null_cyl}  ({100*null_cyl/len(refractions):.1f}%)")

    # ---- Add power --------------------------------------------------------
    no_add = sum(1 for r in refractions if r["od_add"] is None)
    print(f"\n[Add Power]  (None = age < 40 or not recorded)")
    print(f"  None : {no_add}  ({100*no_add/len(refractions):.1f}%)")

    # ---- IOP stats --------------------------------------------------------
    iops = [r["iop_od"] for r in refractions]
    print(f"\n[IOP OD — log-normal, right-skewed]")
    print(f"  Min  : {min(iops):.1f} mmHg")
    print(f"  Max  : {max(iops):.1f} mmHg")
    print(f"  Mean : {statistics.mean(iops):.1f} mmHg")
    print(f"  Elevated (>21): {sum(1 for v in iops if v > 21)}  "
          f"({100*sum(1 for v in iops if v > 21)/len(iops):.1f}%)")

    # ---- Timestamp spot-check ---------------------------------------------
    created_hours = []
    for p in patients:
        ts = datetime.fromtimestamp(p["created"])
        created_hours.append(ts.weekday())
    weekend_regs = sum(1 for wd in created_hours if wd >= 5)
    print(f"\n[Registration timestamps]")
    print(f"  Weekend registrations : {weekend_regs}  (should be 0)")

    print("\n" + "=" * 60)
    print("  Verification complete.")
    print("=" * 60)
