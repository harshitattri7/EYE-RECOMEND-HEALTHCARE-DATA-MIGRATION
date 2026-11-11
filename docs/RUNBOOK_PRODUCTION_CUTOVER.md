# Production Cutover Runbook & Rollback Strategy
### Project: Eye Recommend Healthcare Data Migration
**Document Classification:** Production Confidential / Regulatory Healthcare Compliance

---

## 1. Cutover Objectives & SLA Thresholds
- **Maximum Tolerable Downtime (MTD):** Under 30 minutes of scheduled maintenance window.
- **Data Loss Tolerance (RPO):** Zero records (0.000% variance).
- **Target Reconciliation Accuracy:** &gt; 99.999% across row counts and cryptographic checksums.
- **Rollback Window:** Decision checkpoint at T-5 minutes prior to DNS cutover.

---

## 2. Chronological Cutover Execution Schedule (T-Timeline)

```
[T-120 Min]  Pre-flight Infrastructure & Credentials Health Check
     |
[T-60 Min]   Source Freeze: MariaDB Read-Only & Salesforce Freeze
     |
[T-30 Min]   Queue Drain & Final Delta Watermark Catchup Sync
     |
[T-10 Min]   Automated Source vs Target Reconciliation Audit
     |
[T-05 Min]   Go / No-Go Executive Sign-off Checkpoint
     |
[T-00 Min]   TRAFFIC CUTOVER: Route DNS & Apps to Azure PostgreSQL
     |
[T+15 Min]   Post-Cutover Clinical Workflow Smoke Tests
     |
[T+60 Min]   Production Stability Verification & Final Sign-off
```

### Phase Details

#### Step 1: Pre-flight Verification (T-120 Minutes)
- Verify Azure PostgreSQL Flexible Server read/write health.
- Test Azure Key Vault secret accessibility (`target-postgres-connection-string`, `mariadb-svc-password`).
- Verify Azure Data Factory runtime integration status and Databricks cluster availability.
- Confirm ADLS Gen2 container permissions.

#### Step 2: Source System Freeze (T-60 Minutes)
- **MariaDB EHR**:
  ```sql
  SET GLOBAL read_only = ON;
  FLUSH TABLES WITH READ LOCK;
  ```
- **Salesforce CRM**:
  - Assign all standard clinical and billing users to "Read Only Maintenance Profile".
  - Freeze active API integration user tokens.

#### Step 3: Queue Drain & Final Delta Synchronization (T-30 Minutes)
- Drain remaining Kafka / RabbitMQ in-flight transaction queues.
- Trigger final ADF Delta Sync pipeline `pl_incremental_watermark_sync`.
- Confirm high watermarks in `metadata_ops.watermark_registry` match latest source change timestamps.

#### Step 4: Automated Reconciliation Audit (T-10 Minutes)
- Execute `scripts/reconciliation_engine.py --mode prod`.
- Validate that all audited tables show **0.0000% variance** and **CHECKSUM MATCH**.
- Export signed audit report to `reports/reconciliation_report.md`.

#### Step 5: Go / No-Go Executive Checkpoint (T-05 Minutes)
- Attendees: Data Engineering Lead (Harshit Attri), QA Lead, VP of Engineering, Lead Clinician.
- Unanimous approval required to proceed.

#### Step 6: Traffic Cutover (T-00 Minutes)
- Update Azure Traffic Manager / Front Door to route web traffic to new microservices.
- Update Kubernetes backend connection secrets to target Azure PostgreSQL Flexible Server.
- Warm database connection pools.

#### Step 7: Post-Cutover Smoke Tests (T+15 Minutes)
- Verify Patient Search latency (&lt; 15ms).
- Verify Optometry exam recording and refraction save workflows.
- Verify Salesforce CRM bidirectional synchronization.
- Verify billing invoice generation and claims transmission.

---

## 3. Rollback Strategy & Abort Protocol

### Triggers for Immediate Rollback:
1. Reconciliation variance exceeds 0.001% on any core domain table.
2. Unrecoverable database transaction failure during final incremental sync.
3. Backend service response time &gt; 500ms on post-cutover smoke tests.

### Rollback Execution Steps:
1. **Revert DNS / Front Door**: Instantly route frontend traffic back to legacy Drupal MariaDB endpoints.
2. **Release Source Freeze**:
   ```sql
   SET GLOBAL read_only = OFF;
   UNLOCK TABLES;
   ```
3. **Restore Salesforce Profiles**: Remove Read Only Maintenance Profile.
4. **Log Incident**: Record telemetry in `metadata_ops.pipeline_telemetry_events` and schedule post-mortem analysis.
