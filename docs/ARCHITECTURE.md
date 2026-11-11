# Eye Recommend Healthcare Data Migration - Enterprise Architecture

## 1. Architectural Overview

The **Eye Recommend Healthcare Data Migration** platform is an enterprise-grade cloud data engineering pipeline engineered to consolidate fragmented legacy clinical systems (Drupal MariaDB) and patient relationship management platforms (Salesforce CRM) into a unified, centralized **Azure Database for PostgreSQL Flexible Server** hosting **300+ production tables**.

```
+------------------------+      +------------------------+
| Legacy Drupal MariaDB  |      |     Salesforce CRM     |
| (EHR Clinical Systems) |      | (Patients, Billing)    |
+-----------+------------+      +-----------+------------+
            |                               |
            | JDBC (Self-Hosted IR)         | Bulk API 2.0 / REST
            v                               v
    +-----------------------------------------------+
    |         Azure Data Factory (ADF)             |
    |  - Metadata-Driven Parameterized Pipelines    |
    |  - Parallel Ingestion Across 300+ Tables      |
    +-----------------------+-----------------------+
                            |
                            v
+---------------------------------------------------------------+
|         Azure Data Lake Storage Gen2 (Hierarchical)           |
|                                                               |
|  [landing]   --> Raw drops from ADF copy activities           |
|  [bronze]    --> Parquet format with audit metadata headers   |
|  [silver]    --> Cleansed, deduplicated Delta Lake tables     |
|  [gold]      --> Harmonized 300+ table domain models          |
|  [quarantine]--> Rejection sink for failed DQ records         |
+-------------------------------+-------------------------------+
                                |
                                v
+---------------------------------------------------------------+
|        Azure Databricks Lakehouse Processing Engine           |
|                                                               |
|  1. Ingestion & Schema Conformity (PySpark, Delta Lake)       |
|  2. HIPAA Safe Harbor De-identification & Salted Hashing      |
|  3. Master Patient Index (MPI) Entity Resolution Engine       |
|  4. Data Quality & Referential Integrity Assertions           |
|  5. High-Speed Idempotent Upsert Engine                       |
+-------------------------------+-------------------------------+
                                |
                                | High-Throughput Bulk Staging & MERGE
                                v
+---------------------------------------------------------------+
|     Azure Database for PostgreSQL (Flexible Server 15)        |
|                                                               |
|   * core (45 tables)            * pharmacy_medications (35)   |
|   * clinical (55 tables)        * optometry_ophthalmology (45)|
|   * diagnostics_procedures (40) * crm_billing_insurance (50) |
|   * metadata_ops (30 tables)    * Total: 300+ Prod Tables     |
+-------------------------------+-------------------------------+
                                ^
                                | Audited & Validated
+-------------------------------+-------------------------------+
|         Enterprise Governance & Operations Layer              |
|  - Azure Key Vault: HSM-backed secrets & salt rotation        |
|  - Azure Monitor / Log Analytics: Centralized JSON telemetry  |
|  - Automated Reconciliation: Checksum & Count Validation      |
+---------------------------------------------------------------+
```

---

## 2. Medallion Lakehouse Processing Flow

### 2.1 Bronze Layer (Raw Ingestion)
- **Engine**: Azure Data Factory parameterized Copy activities.
- **Format**: Partitioned Apache Parquet / Delta Lake.
- **Audit Columns Enriched**:
  - `_ingest_timestamp`: UTC timestamp of extraction.
  - `_batch_id`: GUID matching `metadata_ops.batch_control_ledger`.
  - `_source_system`: `DRUPAL_MARIADB` or `SALESFORCE_CRM`.

### 2.2 Silver Layer (Cleansing & Curation)
- **Engine**: Azure Databricks (PySpark, Delta Lake).
- **Transformations**:
  - Unnesting of Drupal serialized PHP entity fields.
  - Converting Unix epoch timestamps into ISO UTC timestamps.
  - Harmonizing gender representations (`M`/`F`/`O` to FHIR standard `MALE`/`FEMALE`/`OTHER`).
  - Salesforce 15-character case-sensitive IDs to 18-character case-insensitive IDs.
  - **HIPAA Masking**: Salted SHA-256 hashing for SSNs; display masking for patient names, phone numbers, and email addresses.
  - **Data Quality Engine**: Records failing mandatory constraints (e.g. invalid date of birth, missing MRN) are diverted to `quarantine` container with failed rule metadata.

### 2.3 Gold Layer (Curated Healthcare Domains)
- **Engine**: PySpark with Delta Lake ACID transactions.
- **Transformations**:
  - **Master Patient Index (MPI)**: Deterministic (MRN / SSN) and probabilistic (Jaro-Winkler fuzzy name + DOB) identity matching across MariaDB and Salesforce.
  - Ophthalmic calculation normalization (Sphere, Cylinder, Axis, Add, Tonometry IOP, Pupillary distance).
  - Schema mapping strictly conforming to PostgreSQL 300+ table DDL specifications.

---

## 3. High-Speed PostgreSQL Loading Architecture

Direct `INSERT` statements over JDBC cannot scale to millions of healthcare records. The migration platform achieves 50,000+ records/second throughput using an unlogged staging table swap strategy:

1. **Transaction Begin**: Spark worker opens dedicated connection from pool.
2. **Temporary Unlogged Table**:
   ```sql
   CREATE TEMP TABLE staging_refractions (LIKE optometry_ophthalmology.refractions INCLUDING DEFAULTS) ON COMMIT DROP;
   ```
3. **High-Speed Binary/CSV COPY**: Streaming records directly into `staging_refractions` memory buffer.
4. **Atomic Set-Based Upsert**:
   ```sql
   INSERT INTO optometry_ophthalmology.refractions (refraction_id, encounter_id, patient_id, od_sphere, od_cylinder, ...)
   SELECT refraction_id, encounter_id, patient_id, od_sphere, od_cylinder, ...
   FROM staging_refractions
   ON CONFLICT (refraction_id) DO UPDATE
   SET od_sphere = EXCLUDED.od_sphere,
       od_cylinder = EXCLUDED.od_cylinder,
       updated_at = CURRENT_TIMESTAMP,
       row_version = optometry_ophthalmology.refractions.row_version + 1;
   ```
5. **Transaction Commit**: Guarantees zero partial batch writes, perfect idempotency, and ACID durability.

---

## 4. Security & Compliance (HIPAA, HITECH, HITRUST)

- **Zero Hardcoded Secrets**: All passwords, API tokens, and encryption salts are retrieved via Azure Key Vault using Managed Identities (MSI).
- **Data Protection in Transit**: TLS 1.2+ enforced across MariaDB, Salesforce REST, ADLS Gen2, Databricks, and PostgreSQL Flexible Server.
- **Data Protection at Rest**: Azure Storage Service Encryption (SSE) with customer-managed keys (CMK) in Azure Key Vault.
- **De-identification**: Cryptographic salting prevents dictionary rainbow-table attacks against sensitive patient identifiers.
