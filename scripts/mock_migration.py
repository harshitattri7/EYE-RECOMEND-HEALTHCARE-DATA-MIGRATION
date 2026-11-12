"""
mock_migration.py
-----------------
Local Proof-of-Concept (PoC) migration script using DuckDB.

What this script does (simple explanation for interviews):
  1. Creates an in-memory/on-disk DuckDB database that acts as our "source" system.
  2. Populates it with fake-but-realistic healthcare records.
  3. Copies those records to a "target" schema — just like a real ETL pipeline does.
  4. Intentionally injects 3 known defects into the target to simulate real-world
     migration problems (late-arriving records, transform bugs, quarantined rows).

Why DuckDB?
  DuckDB is a lightweight, zero-setup SQL engine that runs entirely inside Python.
  No server, no Docker, no cloud credits needed. Perfect for a local PoC.

Interview talking points:
  - "I used DuckDB to simulate the source and target databases locally so I could
     test my reconciliation logic without needing actual Azure credentials."
  - "I intentionally introduced controlled defects so the reconciliation engine
     would have something real to catch — not just all-green zeros."
"""

import os
import random
import duckdb

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Where we store the DuckDB database file.
# Using a file (not :memory:) means the reconciliation script can read it too.
DB_PATH = os.path.join(os.path.dirname(__file__), "..", "data", "migration_poc.duckdb")

# Seed for reproducibility — same seed = same records every run.
random.seed(99)

# How many records to generate per table.
NUM_PATIENTS        = 500
NUM_INVOICES        = 300
NUM_TONOMETRY_EXAMS = 200

# The 3 defects we will intentionally inject (keeps the story honest in interviews)
DEFECT_INVOICE_DROPS      = 3   # Simulates late-arriving / not-yet-committed source records
DEFECT_PHONE_CORRUPTIONS  = 5   # Simulates a phone-number transform bug in the pipeline
DEFECT_TONOMETRY_DROPS    = 2   # Simulates rows quarantined by the data quality engine


# ---------------------------------------------------------------------------
# Helper — build simple row data
# ---------------------------------------------------------------------------

def _make_patients(n: int) -> list[dict]:
    """
    Generate n fake patient rows with realistic-ish values.
    We keep this simple — no fancy distributions needed here because
    the generate_synthetic_data.py script handles full realism.
    """
    first_names = ["James", "Mary", "John", "Patricia", "Robert", "Jennifer",
                   "Michael", "Linda", "William", "Elizabeth"]
    last_names  = ["Smith", "Johnson", "Williams", "Brown", "Jones",
                   "Garcia", "Miller", "Davis", "Rodriguez", "Martinez"]
    rows = []
    for i in range(1, n + 1):
        rows.append({
            "patient_id": i,
            "mrn":        f"MRN-EYE-{10000 + i}",
            "first_name": random.choice(first_names),
            "last_name":  random.choice(last_names),
            "age":        random.randint(18, 90),
            "gender":     random.choice(["MALE", "FEMALE"]),
            # Phone in a standard format — the defect will corrupt 5 of these later
            "phone":      f"555-{random.randint(100,999)}-{random.randint(1000,9999)}",
        })
    return rows


def _make_invoices(n: int) -> list[dict]:
    """
    Generate n fake billing invoice rows.
    In a real CRM migration (Salesforce → PostgreSQL), invoices are often the
    trickiest table because they arrive in batches and some land after cut-over.
    """
    rows = []
    for i in range(1, n + 1):
        rows.append({
            "invoice_id":  i,
            "patient_id":  random.randint(1, NUM_PATIENTS),
            "amount_usd":  round(random.uniform(50.0, 800.0), 2),
            "status":      random.choice(["PAID", "PENDING", "OVERDUE"]),
        })
    return rows


def _make_tonometry_exams(n: int) -> list[dict]:
    """
    Generate n fake tonometry (eye pressure) exam rows.
    Two of these will be dropped in the target to simulate quarantined records —
    rows the data quality engine rejected because IOP values were out of range.
    """
    rows = []
    for i in range(1, n + 1):
        rows.append({
            "exam_id":    i,
            "patient_id": random.randint(1, NUM_PATIENTS),
            # Normal IOP is 10-21 mmHg; most rows are fine
            "iop_od":     round(random.uniform(10.0, 22.0), 1),
            "iop_os":     round(random.uniform(10.0, 22.0), 1),
        })
    return rows


# ---------------------------------------------------------------------------
# Core migration logic
# ---------------------------------------------------------------------------

def setup_database(con: duckdb.DuckDBPyConnection):
    """
    Create separate schemas for source and target.
    In a real Azure setup, source = MariaDB/Salesforce, target = PostgreSQL.
    Here, both live in one DuckDB file for simplicity.
    """
    # Schemas act like namespaces — they keep source and target tables separate
    con.execute("CREATE SCHEMA IF NOT EXISTS source_db")
    con.execute("CREATE SCHEMA IF NOT EXISTS target_db")
    print("[setup] Schemas created: source_db, target_db")


def load_source_tables(con: duckdb.DuckDBPyConnection):
    """
    Step 1: Load raw data into the SOURCE schema.
    Think of this as the data that exists in the legacy MariaDB / Salesforce system.
    """
    print("\n[source] Loading source tables...")

    # --- patients ---
    patients = _make_patients(NUM_PATIENTS)
    con.execute("""
        CREATE OR REPLACE TABLE source_db.patients (
            patient_id INTEGER PRIMARY KEY,
            mrn        VARCHAR,
            first_name VARCHAR,
            last_name  VARCHAR,
            age        INTEGER,
            gender     VARCHAR,
            phone      VARCHAR
        )
    """)
    # Insert rows one by one using parameterised queries (safe from SQL injection)
    for row in patients:
        con.execute(
            "INSERT INTO source_db.patients VALUES (?, ?, ?, ?, ?, ?, ?)",
            [row["patient_id"], row["mrn"], row["first_name"],
             row["last_name"], row["age"], row["gender"], row["phone"]]
        )
    print(f"  source_db.patients        → {NUM_PATIENTS} rows loaded")

    # --- invoices ---
    invoices = _make_invoices(NUM_INVOICES)
    con.execute("""
        CREATE OR REPLACE TABLE source_db.invoices (
            invoice_id INTEGER PRIMARY KEY,
            patient_id INTEGER,
            amount_usd DOUBLE,
            status     VARCHAR
        )
    """)
    for row in invoices:
        con.execute(
            "INSERT INTO source_db.invoices VALUES (?, ?, ?, ?)",
            [row["invoice_id"], row["patient_id"], row["amount_usd"], row["status"]]
        )
    print(f"  source_db.invoices        → {NUM_INVOICES} rows loaded")

    # --- tonometry exams ---
    exams = _make_tonometry_exams(NUM_TONOMETRY_EXAMS)
    con.execute("""
        CREATE OR REPLACE TABLE source_db.tonometry_exams (
            exam_id    INTEGER PRIMARY KEY,
            patient_id INTEGER,
            iop_od     DOUBLE,
            iop_os     DOUBLE
        )
    """)
    for row in exams:
        con.execute(
            "INSERT INTO source_db.tonometry_exams VALUES (?, ?, ?, ?)",
            [row["exam_id"], row["patient_id"], row["iop_od"], row["iop_os"]]
        )
    print(f"  source_db.tonometry_exams → {NUM_TONOMETRY_EXAMS} rows loaded")


def run_etl_with_defects(con: duckdb.DuckDBPyConnection):
    """
    Step 2: Copy source → target, then inject 3 controlled defects.

    In a real pipeline, this ETL step would run in Azure Data Factory / Databricks.
    Here we simulate it with SQL COPY statements + deliberate corruption.

    The defects represent REAL problems that happen in production migrations:
      Defect 1: Late-arriving invoices (source committed 3 extra rows after cut-over)
      Defect 2: Phone format transform bug (5 records corrupted by a bad regex)
      Defect 3: Tonometry rows quarantined by the data-quality engine (dropped, not loaded)
    """
    print("\n[etl] Running ETL: source → target...")

    # ---- PATIENTS: copy all rows, then corrupt 5 phone numbers ----
    con.execute("""
        CREATE OR REPLACE TABLE target_db.patients AS
        SELECT * FROM source_db.patients
    """)

    # Pick 5 random patient_ids to corrupt
    # This simulates what happens when a phone normalisation regex has a bug
    victim_ids = con.execute(
        "SELECT patient_id FROM source_db.patients ORDER BY RANDOM() LIMIT ?",
        [DEFECT_PHONE_CORRUPTIONS]
    ).fetchall()
    corrupted_ids = [row[0] for row in victim_ids]

    for pid in corrupted_ids:
        con.execute(
            # 'ERROR' represents a corrupt value that slipped through without validation
            "UPDATE target_db.patients SET phone = 'ERROR' WHERE patient_id = ?",
            [pid]
        )
    print(f"  target_db.patients        → {NUM_PATIENTS} rows (phone corrupted on {DEFECT_PHONE_CORRUPTIONS} rows: ids {corrupted_ids})")

    # ---- INVOICES: copy all rows, then drop the last 3 ----
    con.execute("""
        CREATE OR REPLACE TABLE target_db.invoices AS
        SELECT * FROM source_db.invoices
    """)

    # Drop the highest invoice_ids — simulating late-arriving records
    # (they were committed in Salesforce AFTER the ADF pipeline ran)
    con.execute(f"""
        DELETE FROM target_db.invoices
        WHERE invoice_id IN (
            SELECT invoice_id FROM source_db.invoices
            ORDER BY invoice_id DESC
            LIMIT {DEFECT_INVOICE_DROPS}
        )
    """)
    print(f"  target_db.invoices        → {NUM_INVOICES - DEFECT_INVOICE_DROPS} rows (dropped {DEFECT_INVOICE_DROPS} late-arriving records)")

    # ---- TONOMETRY EXAMS: copy all rows, then drop 2 quarantined records ----
    con.execute("""
        CREATE OR REPLACE TABLE target_db.tonometry_exams AS
        SELECT * FROM source_db.tonometry_exams
    """)

    # Drop 2 rows — simulating records the Data Quality Engine quarantined
    # (e.g., IOP value was 0 or negative, which is physically impossible)
    con.execute(f"""
        DELETE FROM target_db.tonometry_exams
        WHERE exam_id IN (
            SELECT exam_id FROM source_db.tonometry_exams
            ORDER BY exam_id
            LIMIT {DEFECT_TONOMETRY_DROPS}
        )
    """)
    print(f"  target_db.tonometry_exams → {NUM_TONOMETRY_EXAMS - DEFECT_TONOMETRY_DROPS} rows (dropped {DEFECT_TONOMETRY_DROPS} quarantined records)")


def verify_counts(con: duckdb.DuckDBPyConnection):
    """
    Quick sanity check: print source vs target counts for each table.
    This is what the reconciliation engine will do in full detail.
    """
    print("\n[verify] Quick count check (source vs target):")
    tables = ["patients", "invoices", "tonometry_exams"]
    for t in tables:
        src = con.execute(f"SELECT COUNT(*) FROM source_db.{t}").fetchone()[0]
        tgt = con.execute(f"SELECT COUNT(*) FROM target_db.{t}").fetchone()[0]
        status = "✅ OK" if src == tgt else f"⚠️  MISMATCH (delta={tgt - src})"
        print(f"  {t:<25} source={src}  target={tgt}  {status}")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    # Make sure the data/ folder exists
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

    print("=" * 60)
    print("  Eye Recommend — Local Migration PoC (DuckDB)")
    print("=" * 60)
    print(f"  Database file: {DB_PATH}\n")

    # Connect to DuckDB (creates the file if it doesn't exist)
    con = duckdb.connect(DB_PATH)

    setup_database(con)
    load_source_tables(con)
    run_etl_with_defects(con)
    verify_counts(con)

    con.close()

    print("\n[done] Migration PoC complete.")
    print(f"       Run 'python3 scripts/reconciliation_engine.py' for the full audit report.\n")
