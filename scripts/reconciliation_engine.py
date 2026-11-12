"""
reconciliation_engine.py
------------------------
Automated data reconciliation between source and target databases.

What this script does (simple explanation for interviews):
  1. Connects to our local DuckDB database (created by mock_migration.py).
  2. For each table, runs two checks:
       a) Row count check  — does source have the same number of rows as target?
       b) Checksum check   — does the SUM of a numeric column match?
          (A quick way to catch corrupted or altered values, not just missing rows.)
  3. Calculates the variance % (how far off we are from perfect).
  4. Prints a clean table showing PASS / FAIL per table, plus a Root Cause column
     that explains WHY it failed — which is what a real post-migration report needs.

Why this matters in interviews:
  "Reconciliation is the proof that your ETL didn't lose or corrupt data.
   Without it, you can't sign off on a production migration."

Why DuckDB?
  Zero setup. We can run this locally without any cloud credentials.
  In production, the same SQL queries would run against Azure PostgreSQL.
"""

import os
import duckdb

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Path to the DuckDB file created by mock_migration.py
DB_PATH = os.path.join(os.path.dirname(__file__), "..", "data", "migration_poc.duckdb")

# Tolerance: how much variance % is acceptable before we flag a FAIL.
# In a real production migration, this is agreed upfront with the business team.
TOLERANCE_PCT = 0.5   # 0.5% — a realistic threshold, not a fake 0.001%

# Root cause explanations map to expected defects — in a real project, these would
# come from your incident log, not be hardcoded. We hardcode them here because this
# is a PoC and we deliberately introduced the defects ourselves.
KNOWN_ROOT_CAUSES = {
    "invoices":        "3 late-arriving Salesforce records committed after ADF pipeline ran. Flagged for delta-sync in next batch window.",
    "tonometry_exams": "2 rows quarantined by Data Quality Engine (IOP value out of physiological range). Sent to dq_quarantine_records table for manual review.",
    "patients":        "5 phone numbers corrupted to 'ERROR' by a phone-normalisation regex bug in the Silver-layer transform. Fix deployed; reprocessing queued.",
}

# ---------------------------------------------------------------------------
# Individual check functions
# ---------------------------------------------------------------------------

def check_row_counts(con: duckdb.DuckDBPyConnection, table: str) -> dict:
    """
    The most basic reconciliation check: count rows in source vs target.

    If source has 300 rows and target has 297, something went wrong —
    either rows were dropped, quarantined, or the pipeline crashed mid-load.

    Returns a dict with the counts, delta, and variance %.
    """
    # COUNT(*) = count every row regardless of NULLs
    src_count = con.execute(f"SELECT COUNT(*) FROM source_db.{table}").fetchone()[0]
    tgt_count = con.execute(f"SELECT COUNT(*) FROM target_db.{table}").fetchone()[0]

    delta = tgt_count - src_count           # negative means target is missing rows
    # Variance % = how far off we are as a percentage of the source count
    variance_pct = 0.0 if src_count == 0 else abs(delta / src_count) * 100.0

    return {
        "src_count":    src_count,
        "tgt_count":    tgt_count,
        "delta":        delta,
        "variance_pct": round(variance_pct, 4),
    }


def check_checksum(con: duckdb.DuckDBPyConnection, table: str, numeric_col: str) -> dict:
    """
    A simple checksum: SUM a numeric column in both source and target.

    Why do this? Because even if row counts match, values could be wrong.
    Example: 300 rows in both tables, but one row had its invoice amount
    changed from $150 to $0 — the row count wouldn't catch that, but
    the SUM would (source SUM ≠ target SUM).

    In production you'd use MD5 or SHA-256 checksums on entire rows.
    SUM is simpler and easier to explain in an interview setting.
    """
    # COALESCE(..., 0) replaces NULLs with 0 so SUM never returns NULL
    src_sum = con.execute(
        f"SELECT COALESCE(SUM({numeric_col}), 0) FROM source_db.{table}"
    ).fetchone()[0]
    tgt_sum = con.execute(
        f"SELECT COALESCE(SUM({numeric_col}), 0) FROM target_db.{table}"
    ).fetchone()[0]

    match = abs(src_sum - tgt_sum) < 0.01   # allow tiny float rounding differences

    return {
        "src_sum":      round(src_sum, 2),
        "tgt_sum":      round(tgt_sum, 2),
        "checksum_ok":  match,
    }


def count_corrupted_phones(con: duckdb.DuckDBPyConnection) -> int:
    """
    Special check for the patients table: count how many phone values
    are the literal string 'ERROR' — a sign of a transform bug.

    This kind of domain-specific check is what separates a good
    reconciliation from a lazy one. Row counts can look fine while
    data quality is broken inside.
    """
    result = con.execute(
        "SELECT COUNT(*) FROM target_db.patients WHERE phone = 'ERROR'"
    ).fetchone()[0]
    return result


# ---------------------------------------------------------------------------
# Main reconciliation runner
# ---------------------------------------------------------------------------

def run_reconciliation(con: duckdb.DuckDBPyConnection) -> list[dict]:
    """
    Run all reconciliation checks and return a list of result dicts —
    one per table — ready to be printed as a report.

    Tables and their numeric columns we checksum against:
      patients        → SUM(patient_id)   simple proxy; prod would use MD5(all columns)
      invoices        → SUM(amount_usd)   the most important financial integrity check
      tonometry_exams → SUM(iop_od)       clinical data integrity check
    """
    table_config = [
        # (table_name,       numeric_col_for_checksum,  domain_label)
        ("patients",        "patient_id",  "clinical.patients"),
        ("invoices",        "amount_usd",  "crm_billing_insurance.invoices"),
        ("tonometry_exams", "iop_od",      "optometry_ophthalmology.tonometry_exams"),
    ]

    results = []

    for table, numeric_col, domain_label in table_config:
        # --- Run both checks ---
        counts   = check_row_counts(con, table)
        checksum = check_checksum(con, table, numeric_col)

        # --- Determine overall verdict ---
        # We FAIL if: (a) variance is over tolerance, OR (b) checksum doesn't match
        row_count_pass = counts["variance_pct"] <= TOLERANCE_PCT
        checksum_pass  = checksum["checksum_ok"]
        overall_pass   = row_count_pass and checksum_pass

        # --- Extra domain check for patients table ---
        corrupted_phones = count_corrupted_phones(con) if table == "patients" else 0
        if corrupted_phones > 0:
            overall_pass = False   # corrupt phones = data quality failure even if counts match

        # --- Look up root cause (if known) ---
        root_cause = KNOWN_ROOT_CAUSES.get(table, "No known defect — investigate pipeline logs.")

        results.append({
            "domain_label":      domain_label,
            "src_count":         counts["src_count"],
            "tgt_count":         counts["tgt_count"],
            "delta":             counts["delta"],
            "variance_pct":      counts["variance_pct"],
            "src_sum":           checksum["src_sum"],
            "tgt_sum":           checksum["tgt_sum"],
            "checksum_ok":       checksum["checksum_ok"],
            "corrupted_phones":  corrupted_phones,
            "verdict":           "PASS" if overall_pass else "FAIL",
            "root_cause":        root_cause if not overall_pass else "None — data integrity verified.",
        })

    return results


# ---------------------------------------------------------------------------
# Terminal report printer
# ---------------------------------------------------------------------------

def print_report(results: list[dict]):
    """
    Print a clean, readable terminal table.
    Wide columns make it easy to read in a GitHub README screenshot too.
    """

    # ---- Header ----
    print()
    print("=" * 80)
    print("  Eye Recommend Healthcare Migration — Reconciliation Audit Report")
    print("  Local Migration PoC (Proof of Concept) | DuckDB")
    print("=" * 80)
    print(f"  Tolerance threshold : {TOLERANCE_PCT}%  "
          f"(variance below this = acceptable)")
    print()

    # ---- Per-table results ----
    for r in results:
        verdict_icon = "✅ PASS" if r["verdict"] == "PASS" else "❌ FAIL"
        chk_icon     = "✅ MATCH"  if r["checksum_ok"] else "❌ MISMATCH"

        print(f"  Table   : {r['domain_label']}")
        print(f"  ┌─────────────────────────────────────────────")
        print(f"  │ Row count   source={r['src_count']:>6}  "
              f"target={r['tgt_count']:>6}  "
              f"delta={r['delta']:>4}  "
              f"variance={r['variance_pct']:.4f}%")
        print(f"  │ Checksum    source={r['src_sum']:>12.2f}  "
              f"target={r['tgt_sum']:>12.2f}  {chk_icon}")

        if r["corrupted_phones"] > 0:
            print(f"  │ ⚠️  Corrupt phones detected in target: {r['corrupted_phones']} rows with phone='ERROR'")

        print(f"  │ Verdict  : {verdict_icon}")
        print(f"  │ Root cause: {r['root_cause']}")
        print(f"  └─────────────────────────────────────────────")
        print()

    # ---- Summary ----
    total  = len(results)
    passed = sum(1 for r in results if r["verdict"] == "PASS")
    failed = total - passed

    print("─" * 80)
    print(f"  SUMMARY: {passed}/{total} tables PASSED  |  {failed}/{total} tables FAILED")
    print()

    if failed > 0:
        print("  ACTION REQUIRED:")
        for r in results:
            if r["verdict"] == "FAIL":
                print(f"    • [{r['domain_label']}] → {r['root_cause']}")
        print()
        print("  Cutover Decision : ⛔  HOLD — resolve above issues before go-live.")
    else:
        print("  Cutover Decision : ✅  GO — all tables within tolerance.")

    print()
    print("  Migration Engineer: Harshit Attri")
    print("=" * 80)
    print()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    # Check that the database file exists — tell the user to run mock_migration.py first
    if not os.path.exists(DB_PATH):
        print(f"\n[ERROR] Database not found at: {DB_PATH}")
        print("        Please run this first:\n")
        print("          python3 scripts/mock_migration.py\n")
        raise SystemExit(1)

    # Open the database in READ-ONLY mode — reconciliation should never modify data
    con = duckdb.connect(DB_PATH, read_only=True)

    results = run_reconciliation(con)
    print_report(results)

    con.close()
