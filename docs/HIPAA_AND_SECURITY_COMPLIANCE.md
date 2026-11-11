# HIPAA & Security Compliance Specification
### Project: Eye Recommend Healthcare Data Migration
**Standards:** HIPAA Safe Harbor Method (45 CFR § 164.514(b)), HITRUST CSF, SOC 2 Type II

---

## 1. Compliance Architecture Overview
Healthcare migrations demand stringent governance to prevent unauthorized disclosure of Protected Health Information (PHI). The migration platform strictly enforces HIPAA Safe Harbor de-identification and cryptographic access boundaries across all pipelines.

---

## 2. Protected Health Information (PHI) Handling Matrix

| PHI Attribute | HIPAA Safe Harbor Requirement | Migration Platform Implementation |
| :--- | :--- | :--- |
| **Social Security Number (SSN)** | Must be removed or de-identified | Irreversibly hashed via SHA-256 with Azure Key Vault salt; strictly last 4 digits stored for operational verification. |
| **Patient Names** | Direct identifier | First character retained followed by asterisks (e.g. `J*** D**`) in public reporting; raw values encrypted at rest using AES-256-GCM. |
| **Phone & Email** | Direct identifier | Masked in presentation layers (`(555) ***-2831`, `j***e@domain.com`). |
| **Dates (DOB, Exam Dates)** | All dates directly related to an individual | Preserved in secured production database for clinical validity; date shifting applied in non-production environments. |
| **Medical Record Number (MRN)** | Unique identifier | Converted into deterministic pseudonymous UUIDs for internal pipeline linkages. |

---

## 3. Cryptographic Secret Management & Key Vault Rotation
- **Zero Credentials in Git / Repositories**: All database connection strings, passwords, and API tokens are managed in **Azure Key Vault** (SKU: Premium HSM).
- **Service Principal & Managed Identity (MSI)**: Azure Data Factory and Azure Databricks authenticate to Azure Key Vault and ADLS Gen2 using Azure Active Directory System-Assigned Managed Identities.
- **Access Boundary**: Key Vault network ACLs restrict traffic strictly to designated Azure private endpoints.

---

## 4. Encryption Standards
- **Encryption at Rest**:
  - Azure Data Lake Storage Gen2: 256-bit AES encryption (SSE).
  - Azure Database for PostgreSQL Flexible Server: Storage encryption with customer-managed keys (CMK).
- **Encryption in Transit**:
  - Enforced TLS 1.2+ with forward secrecy across all JDBC, REST, and database network interfaces.
  - Plaintext HTTP / non-SSL database traffic is permanently disabled at the network firewall level.

---

## 5. Audit Logging & Access Traceability
- Every query accessing PHI is logged in `core.patient_audit_event_log` with operator identity, IP address, and timestamp.
- Databricks job execution logs and Azure Data Factory execution events are forwarded to **Azure Log Analytics** with a 90-day immutable retention window.
