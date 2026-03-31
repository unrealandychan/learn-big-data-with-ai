# Data Governance & Access Control

## Learning Outcomes
- Implement comprehensive data governance
- Design role-based access control (RBAC)
- **Manage governance infrastructure as code (Terraform)**
- Catalog and track data lineage
- Comply with privacy regulations (GDPR, CCPA)
- Establish data stewardship

**Estimated Time:** 4 hours  
**Prerequisites:** Governance Module 01-03, basic Terraform familiarity

## RBAC Implementation by Platform

### Snowflake RBAC
```sql
-- Create roles with hierarchy
CREATE ROLE analyst;
CREATE ROLE senior_analyst;
CREATE ROLE data_steward;

-- Grant privileges
GRANT USAGE ON DATABASE analytics TO analyst;
GRANT USAGE ON SCHEMA analytics.raw TO analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics.raw TO analyst;

-- Higher-level access
GRANT SELECT ON ALL TABLES IN SCHEMA analytics.processed TO senior_analyst;
GRANT INSERT ON ALL TABLES IN SCHEMA analytics.processed TO senior_analyst;

-- Grant roles to users
GRANT ROLE analyst TO USER 'john.doe@company.com';
GRANT ROLE senior_analyst TO ROLE analyst;  -- Role hierarchy

-- Column-level security (masking)
CREATE OR ALTER MASKING POLICY email_masking AS (email STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE IN ('data_steward', 'admin') THEN email
    ELSE CONCAT(LEFT(email, 3), '***@company.com')
  END;

ALTER TABLE customers MODIFY COLUMN email SET MASKING POLICY email_masking;
```

### Databricks RBAC (Unity Catalog)
```sql
-- Create catalog-level access
CREATE CATALOG enterprise_data;

CREATE SCHEMA enterprise_data.analytics;

-- Grant permissions
GRANT USAGE ON CATALOG enterprise_data TO group_name;
GRANT SELECT ON SCHEMA enterprise_data.analytics TO group_name;
GRANT MODIFY ON TABLE enterprise_data.analytics.orders TO analyst_group;

-- Column-level permissions
ALTER TABLE enterprise_data.analytics.customers
MODIFY COLUMN ssn
SET TAG pii_level = 'sensitive';

-- Grant based on tag
GRANT SELECT ON TABLE enterprise_data.analytics.*
WHERE pii_level = 'public'
TO group_name;
```

### BigQuery IAM
```yaml
# Google Cloud IAM roles
- role: roles/bigquery.dataEditor
  members:
    - group:analytics@company.com
    - serviceAccount:dbt@project.iam.gserviceaccount.com

- role: roles/bigquery.dataViewer
  members:
    - group:business-users@company.com

- role: roles/bigquery.admin
  members:
    - group:data-admins@company.com

# Row-level security with authorized views
CREATE OR REPLACE VIEW analytics.sales_by_region AS
SELECT * FROM raw.sales
WHERE region = SESSION_USER();
```

### Redshift IAM + Schema
```sql
-- Create roles
CREATE ROLE analyst;
CREATE ROLE data_engineer;

-- Schema-level access
GRANT USAGE ON SCHEMA raw TO data_engineer;
GRANT USAGE ON SCHEMA analytics TO analyst;

-- Specific table access
GRANT SELECT ON TABLE transactions TO analyst;
GRANT INSERT ON TABLE staging_orders TO data_engineer;

-- Dynamic row security (via views)
CREATE VIEW analyst_view AS
SELECT * FROM sales WHERE region = CURRENT_USER_ID()
WITH LOCAL CHECK OPTION;

GRANT SELECT ON ANALYST_VIEW TO analyst;
```

---

## Infrastructure as Code (IaC) for Governance

The SQL commands above create roles and grants interactively — but that means they live only in your brain and your terminal history. **IaC solves this:**

| Problem with manual SQL grants | IaC solution |
|--------------------------------|-------------|
| "Who gave John access to prod?" | Every change is a git commit with author + message |
| Dev and prod permissions drift | Apply the same Terraform plan to every environment |
| No review process for access changes | Access changes go through a Pull Request |
| Onboarding a new team takes a day | `terraform apply` — done in minutes |
| Accidental `GRANT ALL` in prod | `terraform plan` shows a diff before anything changes |

All four platforms have mature Terraform providers. The pattern is identical: **describe desired state in `.tf` files → `terraform plan` → review → `terraform apply`**.

---

### Terraform Project Structure

```
governance/
├── main.tf                  # Provider config, backend state
├── variables.tf             # Environment-agnostic inputs
├── terraform.tfvars         # Dev values  (don't commit secrets)
├── terraform.prod.tfvars    # Prod values (use CI secrets)
│
├── modules/
│   ├── snowflake-rbac/      # Reusable Snowflake role module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── databricks-unity/    # Unity Catalog grants module
│   ├── bigquery-iam/        # BigQuery IAM bindings module
│   └── redshift-iam/        # Redshift + AWS IAM module
│
└── environments/
    ├── dev/
    │   └── main.tf          # Calls modules with dev vars
    └── prod/
        └── main.tf          # Calls modules with prod vars
```

---

### 1. Snowflake RBAC — Terraform

```hcl
# governance/modules/snowflake-rbac/variables.tf
variable "database_name" { type = string }
variable "analysts"       { type = list(string) }
variable "engineers"      { type = list(string) }
```

```hcl
# governance/modules/snowflake-rbac/main.tf
terraform {
  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.87"
    }
  }
}

# ── Roles ──────────────────────────────────────────────────────────
resource "snowflake_role" "analyst" {
  name    = "ANALYST"
  comment = "Read access to processed schema"
}

resource "snowflake_role" "senior_analyst" {
  name    = "SENIOR_ANALYST"
  comment = "Read + write access to processed schema"
}

resource "snowflake_role" "data_steward" {
  name    = "DATA_STEWARD"
  comment = "Full access including PII columns"
}

# Role hierarchy: senior_analyst inherits analyst
resource "snowflake_role_grants" "senior_inherits_analyst" {
  role_name = snowflake_role.analyst.name
  roles     = [snowflake_role.senior_analyst.name]
}

# ── Database + Schema grants ────────────────────────────────────────
resource "snowflake_database_grant" "analyst_usage" {
  database_name = var.database_name
  privilege     = "USAGE"
  roles         = [snowflake_role.analyst.name]
}

resource "snowflake_schema_grant" "analyst_raw_usage" {
  database_name = var.database_name
  schema_name   = "RAW"
  privilege     = "USAGE"
  roles         = [snowflake_role.analyst.name]
}

resource "snowflake_table_grant" "analyst_raw_select" {
  database_name = var.database_name
  schema_name   = "RAW"
  privilege     = "SELECT"
  roles         = [snowflake_role.analyst.name]
  on_all        = true
}

resource "snowflake_table_grant" "senior_processed_select" {
  database_name = var.database_name
  schema_name   = "PROCESSED"
  privilege     = "SELECT"
  roles         = [snowflake_role.senior_analyst.name]
  on_all        = true
}

# ── Assign roles to users ───────────────────────────────────────────
resource "snowflake_user_grant" "analysts" {
  for_each  = toset(var.analysts)
  user_name = each.value
  roles     = [snowflake_role.analyst.name]
}

resource "snowflake_user_grant" "engineers" {
  for_each  = toset(var.engineers)
  user_name = each.value
  roles     = [snowflake_role.senior_analyst.name]
}

# ── Column masking policy ───────────────────────────────────────────
resource "snowflake_masking_policy" "email_mask" {
  name     = "EMAIL_MASKING"
  database = var.database_name
  schema   = "PROCESSED"

  signature {
    column {
      name = "email"
      type = "STRING"
    }
  }

  masking_expression = <<-EOT
    CASE
      WHEN CURRENT_ROLE() IN ('DATA_STEWARD', 'ACCOUNTADMIN') THEN email
      ELSE CONCAT(LEFT(email, 3), '***@hidden.com')
    END
  EOT

  return_data_type = "STRING"
  comment          = "Masks email for non-steward roles"
}

resource "snowflake_masking_policy_application" "apply_email_mask" {
  table   = "${var.database_name}.PROCESSED.CUSTOMERS"
  column  = "EMAIL"
  masking_policy = snowflake_masking_policy.email_mask.qualified_name
}
```

```hcl
# governance/environments/prod/main.tf
module "snowflake_rbac" {
  source        = "../../modules/snowflake-rbac"
  database_name = "ANALYTICS_PROD"
  analysts      = ["john.doe@company.com", "jane.smith@company.com"]
  engineers     = ["alice.eng@company.com"]
}
```

---

### 2. Databricks Unity Catalog — Terraform

```hcl
# governance/modules/databricks-unity/main.tf
terraform {
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.36"
    }
  }
}

variable "catalog_name"     { type = string }
variable "analyst_group"    { type = string }
variable "engineer_group"   { type = string }

# ── Catalog ─────────────────────────────────────────────────────────
resource "databricks_catalog" "enterprise" {
  name    = var.catalog_name
  comment = "Primary analytics catalog — managed by Terraform"
}

# ── Schemas ─────────────────────────────────────────────────────────
resource "databricks_schema" "analytics" {
  catalog_name = databricks_catalog.enterprise.name
  name         = "analytics"
  comment      = "Curated analytics layer"
}

resource "databricks_schema" "raw" {
  catalog_name = databricks_catalog.enterprise.name
  name         = "raw"
  comment      = "Raw ingestion layer — restricted"
}

# ── Groups ──────────────────────────────────────────────────────────
resource "databricks_group" "analysts" {
  display_name = var.analyst_group
}

resource "databricks_group" "engineers" {
  display_name = var.engineer_group
}

# ── Grants ──────────────────────────────────────────────────────────
resource "databricks_grants" "catalog_usage" {
  catalog = databricks_catalog.enterprise.name

  grant {
    principal  = databricks_group.analysts.display_name
    privileges = ["USE_CATALOG"]
  }

  grant {
    principal  = databricks_group.engineers.display_name
    privileges = ["USE_CATALOG", "CREATE_SCHEMA"]
  }
}

resource "databricks_grants" "analytics_schema" {
  schema = "${databricks_catalog.enterprise.name}.${databricks_schema.analytics.name}"

  grant {
    principal  = databricks_group.analysts.display_name
    privileges = ["USE_SCHEMA", "SELECT"]
  }

  grant {
    principal  = databricks_group.engineers.display_name
    privileges = ["USE_SCHEMA", "SELECT", "MODIFY", "CREATE_TABLE"]
  }
}

# Engineers only on raw — analysts cannot see raw schema
resource "databricks_grants" "raw_schema" {
  schema = "${databricks_catalog.enterprise.name}.${databricks_schema.raw.name}"

  grant {
    principal  = databricks_group.engineers.display_name
    privileges = ["USE_SCHEMA", "SELECT", "MODIFY", "CREATE_TABLE"]
  }
}

# ── PII Tags (column-level) ─────────────────────────────────────────
resource "databricks_sql_table" "customers" {
  catalog_name = databricks_catalog.enterprise.name
  schema_name  = databricks_schema.analytics.name
  name         = "customers"
  table_type   = "MANAGED"

  column {
    name    = "customer_id"
    type    = "BIGINT"
  }
  column {
    name    = "email"
    type    = "STRING"
    comment = "PII:email"         # picked up by automated PII scanner
  }
  column {
    name    = "full_name"
    type    = "STRING"
    comment = "PII:name"
  }
}
```

---

### 3. BigQuery IAM — Terraform

```hcl
# governance/modules/bigquery-iam/main.tf
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "project_id"        { type = string }
variable "dataset_id"        { type = string }
variable "analytics_group"   { type = string }   # e.g. "group:analytics@company.com"
variable "biz_users_group"   { type = string }
variable "dbt_sa"            { type = string }   # e.g. "serviceAccount:dbt@project.iam.gserviceaccount.com"

# ── Dataset ─────────────────────────────────────────────────────────
resource "google_bigquery_dataset" "analytics" {
  dataset_id                 = var.dataset_id
  project                    = var.project_id
  location                   = "US"
  delete_contents_on_destroy = false

  labels = {
    env         = "prod"
    managed_by  = "terraform"
    data_domain = "analytics"
  }
}

# ── Dataset-level IAM ───────────────────────────────────────────────
resource "google_bigquery_dataset_iam_binding" "editors" {
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataEditor"

  members = [
    var.analytics_group,
    var.dbt_sa,
  ]
}

resource "google_bigquery_dataset_iam_binding" "viewers" {
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  project    = var.project_id
  role       = "roles/bigquery.dataViewer"
  members    = [var.biz_users_group]
}

# ── Table-level IAM (more granular) ────────────────────────────────
resource "google_bigquery_table_iam_member" "orders_viewer" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  table_id   = "fct_orders"
  role       = "roles/bigquery.dataViewer"
  member     = var.biz_users_group
}

# ── Row-level security (authorized view) ───────────────────────────
resource "google_bigquery_table" "sales_by_region_view" {
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  project    = var.project_id
  table_id   = "sales_by_region"

  view {
    query = <<-SQL
      SELECT *
      FROM `${var.project_id}.raw.sales`
      WHERE region = SESSION_USER()
    SQL
    use_legacy_sql = false
  }
}

# Authorize the view to access the raw dataset
resource "google_bigquery_dataset_access" "authorized_view" {
  dataset_id = "raw"
  project    = var.project_id

  view {
    project_id = var.project_id
    dataset_id = google_bigquery_dataset.analytics.dataset_id
    table_id   = google_bigquery_table.sales_by_region_view.table_id
  }
}

# ── Column-level security (policy tags) ────────────────────────────
resource "google_data_catalog_taxonomy" "pii_taxonomy" {
  project                = var.project_id
  region                 = "us"
  display_name           = "PII Classification"
  description            = "Tags for classifying sensitive columns"
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]
}

resource "google_data_catalog_policy_tag" "email_tag" {
  taxonomy     = google_data_catalog_taxonomy.pii_taxonomy.id
  display_name = "Email"
  description  = "Email addresses — PII under GDPR/CCPA"
}

resource "google_bigquery_datapolicy_data_policy" "email_mask" {
  project          = var.project_id
  location         = "us"
  data_policy_id   = "email_masking_policy"
  policy_tag       = google_data_catalog_policy_tag.email_tag.name
  data_policy_type = "DATA_MASKING_POLICY"

  data_masking_policy {
    predefined_expression = "EMAIL_MASK"
  }
}
```

---

### 4. Redshift + AWS IAM — Terraform

```hcl
# governance/modules/redshift-iam/main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "cluster_id"     { type = string }
variable "database_name"  { type = string }
variable "analyst_arns"   { type = list(string) }

# ── IAM policy for Redshift read-only access ────────────────────────
resource "aws_iam_policy" "redshift_analyst" {
  name        = "RedshiftAnalystAccess"
  description = "Read-only Redshift access for analysts — managed by Terraform"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "redshift:GetClusterCredentials",
          "redshift:CreateClusterUser",
          "redshift:JoinGroup",
        ]
        Resource = [
          "arn:aws:redshift:*:*:cluster:${var.cluster_id}",
          "arn:aws:redshift:*:*:dbname:${var.cluster_id}/${var.database_name}",
          "arn:aws:redshift:*:*:dbuser:${var.cluster_id}/analyst_*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["redshift-data:ExecuteStatement", "redshift-data:GetStatementResult"]
        Resource = "*"
      }
    ]
  })
}

# ── IAM role for dbt service account ────────────────────────────────
resource "aws_iam_role" "dbt_role" {
  name = "DbtRedshiftRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    ManagedBy   = "terraform"
    Purpose     = "dbt pipeline service account"
    Environment = "prod"
  }
}

resource "aws_iam_role_policy_attachment" "dbt_s3_access" {
  role       = aws_iam_role.dbt_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# ── Parameter group (enforce SSL) ───────────────────────────────────
resource "aws_redshift_parameter_group" "enforce_ssl" {
  name   = "enforce-ssl-params"
  family = "redshift-1.0"

  parameter {
    name  = "require_ssl"
    value = "true"
  }

  parameter {
    name  = "enable_user_activity_logging"
    value = "true"
  }
}

# ── Attach parameter group to cluster ───────────────────────────────
resource "aws_redshift_cluster" "main" {
  cluster_identifier    = var.cluster_id
  database_name         = var.database_name
  cluster_parameter_group_name = aws_redshift_parameter_group.enforce_ssl.name

  # Don't manage the whole cluster here if it already exists — use:
  # lifecycle { ignore_changes = [master_password] }
  lifecycle {
    ignore_changes = [master_password, number_of_nodes]
  }
}
```

---

### 5. Shared Variables and State Backend

```hcl
# governance/main.tf
terraform {
  required_version = ">= 1.6"

  # Remote state — never use local state for shared governance
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "governance/prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"   # prevents concurrent applies
    encrypt        = true
  }
}

# governance/variables.tf
variable "environment" {
  type        = string
  description = "dev | staging | prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}

variable "snowflake_account" { type = string }
variable "gcp_project_id"    { type = string }
variable "aws_region"        { type = string  default = "us-east-1" }

# governance/terraform.tfvars  ← DO NOT COMMIT — add to .gitignore
# snowflake_account = "xy12345.us-east-1"
# gcp_project_id    = "my-company-prod"
# environment       = "prod"
```

---

### 6. CI/CD Pipeline for Governance Changes

Every access change should go through a PR. This GitHub Actions workflow runs `terraform plan` on every PR so reviewers can see exactly what access is being added or removed before merge.

```yaml
# .github/workflows/governance.yml
name: Governance IaC

on:
  pull_request:
    paths:
      - 'governance/**'         # only run when governance files change
  push:
    branches: [main]
    paths:
      - 'governance/**'

env:
  TF_VERSION: "1.7.0"
  WORKING_DIR: "./governance"

jobs:
  plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'

    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS credentials (for S3 backend + Redshift)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region:            us-east-1

      - name: Terraform Init
        working-directory: ${{ env.WORKING_DIR }}
        run: terraform init

      - name: Terraform Validate
        working-directory: ${{ env.WORKING_DIR }}
        run: terraform validate

      - name: Terraform Plan
        id: plan
        working-directory: ${{ env.WORKING_DIR }}
        env:
          TF_VAR_snowflake_account: ${{ secrets.SNOWFLAKE_ACCOUNT }}
          TF_VAR_gcp_project_id:    ${{ secrets.GCP_PROJECT_ID }}
          TF_VAR_environment:       "prod"
        run: terraform plan -no-color -out=tfplan 2>&1 | tee plan_output.txt

      - name: Post plan as PR comment
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('${{ env.WORKING_DIR }}/plan_output.txt', 'utf8');
            const truncated = plan.length > 60000 ? plan.slice(-60000) + '\n...(truncated)' : plan;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Governance Terraform Plan\n\`\`\`hcl\n${truncated}\n\`\`\``
            });

  apply:
    name: Terraform Apply
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    environment: production           # requires manual approval in GitHub

    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region:            us-east-1

      - name: Terraform Init
        working-directory: ${{ env.WORKING_DIR }}
        run: terraform init

      - name: Terraform Apply
        working-directory: ${{ env.WORKING_DIR }}
        env:
          TF_VAR_snowflake_account: ${{ secrets.SNOWFLAKE_ACCOUNT }}
          TF_VAR_gcp_project_id:    ${{ secrets.GCP_PROJECT_ID }}
          TF_VAR_environment:       "prod"
        run: terraform apply -auto-approve
```

**What this workflow guarantees:**

```
Developer opens PR to add a new analyst
         ↓
GitHub Actions runs terraform plan automatically
         ↓
Plan output posted as PR comment:
  + snowflake_user_grant.analysts["new.person@co.com"]
  (no other changes)
         ↓
Data steward reviews the diff and approves PR
         ↓
Merge to main triggers terraform apply with manual approval gate
         ↓
Access granted — full audit trail in git history
```

---

### 7. Drift Detection

Over time, someone inevitably makes a manual change in the console or via SQL. Drift detection catches this automatically.

```yaml
# Add to governance.yml
  drift-check:
    name: Detect Drift
    runs-on: ubuntu-latest
    # Run nightly to catch manual changes
    if: github.event_name == 'schedule'

    steps:
      - uses: actions/checkout@v4
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
      - name: Terraform Init
        working-directory: ${{ env.WORKING_DIR }}
        run: terraform init
      - name: Terraform Plan (drift)
        working-directory: ${{ env.WORKING_DIR }}
        run: |
          terraform plan -detailed-exitcode
          # Exit code 2 = changes detected (drift)
          # If exit code 2: open a GitHub issue automatically
```

```yaml
# Schedule trigger at the top of governance.yml
on:
  schedule:
    - cron: '0 6 * * *'    # 6 AM UTC daily drift check
  pull_request:
    paths: ['governance/**']
  push:
    branches: [main]
    paths: ['governance/**']
```

---

## Data Cataloging

### Collibra Integration
```yaml
# Metadata Registration:
├─ Asset: customers table
├─ Owner: john.doe@company.com
├─ Steward: analytics-team
├─ Classification: Public
├─ Lineage:
│  ├─ Source: CRM system → bronze
│  ├─ Transform: dbt model stg_customers → silver
│  └─ Usage: fact_orders depends on this
├─ Quality:
│  ├─ Completeness: 99.95%
│  ├─ Freshness: <2 hours
│  └─ SLA: 99.9%
└─ Compliance:
   ├─ GDPR: Yes (requires consent)
   ├─ CCPA: Yes (customer can request deletion)
   └─ PCI: No
```

### Integration with dbt
```yaml
# models/marts/schema.yml
models:
  - name: dim_customers
    meta:
      owner: analytics
      domain: customer
      governance:
        classification: public
        retention: 7_years
        pii: false
    columns:
      - name: ssn
        meta:
          pii: true
          classification: confidential
          encryption: required
```

## Privacy & Compliance

### GDPR Compliance
```sql
-- Right to be forgotten: Delete customer data
CALL anonymize_customer('customer_id_123');
-- Cascading delete from all tables

-- Data subject access request
SELECT *
FROM all_customer_tables
WHERE customer_id = 'customer_id_123'
AND created_date >= DATE_SUB(CURRENT_DATE(), 30);

-- Audit log of access
SELECT
  user,
  table_name,
  query_text,
  access_timestamp
FROM data_access_log
WHERE classification = 'personal_data'
  AND access_timestamp >= '2024-01-01'
ORDER BY access_timestamp DESC;
```

### CCPA Compliance
```sql
-- Portability: Export customer's own data
EXPORT DATA OPTIONS(
  uri = 's3://customer-exports/customer_123/*',
  format = 'CSV'
) AS
SELECT *
FROM customer_profile
WHERE customer_id = 'customer_123';

-- Deletion: Optout customers
UPDATE customer_preferences
SET data_collection_optout = true
WHERE customer_id IN (SELECT id FROM ccpa_deletion_requests)
  AND request_date >= '2024-01-01';

-- Transparency: Log all processing
INSERT INTO data_processing_log
SELECT
  customer_id,
  'profiling',
  'churn_model',
  current_timestamp(),
  'legitimate_interest'
FROM predictions
WHERE model_name = 'churn_predictor';
```

## Data Lineage Tracking

### dbt Lineage
```yaml
# models/marts/fct_orders.yml
models:
  - name: fct_orders
    description: |
      Order transactions fact table
      - Grain: One row per order
      - Updated: Daily via Airflow
      - Use: Revenue analysis, customer funnel
    upstream_models:
      - stg_raw_orders
      - stg_raw_customers
    downstream_models:
      - rpt_monthly_revenue
      - ml_churn_predictor
    tests:
      - unique(order_id)
      - not_null(customer_id)
```

### Lineage Query
```sql
-- Track data lineage through transformations
WITH lineage AS (
  SELECT
    'bronze_orders' as table_name,
    'raw' as layer,
    's3://bucket/orders/' as source,
    current_timestamp() as processed_at
  UNION ALL
  SELECT 'silver_orders', 'cleaned', NULL, current_timestamp()
  UNION ALL
  SELECT 'fct_orders', 'analytics', NULL, current_timestamp()
)
SELECT * FROM lineage;
```

## Key Concepts

- **RBAC:** Role-based access with hierarchy
- **ABAC:** Attribute-based access (tags, classifications)
- **IaC for Governance:** All roles, grants, and masking policies declared as code — version-controlled, peer-reviewed, and automatically applied
- **Drift Detection:** Scheduled `terraform plan` catches manual console changes before they cause security gaps
- **Data Catalog:** Metadata repository for discovery
- **Lineage:** Track data flow through transformations
- **Compliance:** GDPR, CCPA, SOC 2, HIPAA requirements

## Hands-On Lab

### Part 1: RBAC Setup (Manual SQL — understand the primitives)
1. Create analyst and engineer roles
2. Define schema and table permissions
3. Test access restrictions
4. Verify role hierarchy

### Part 2: IaC for Governance (Terraform)
1. Install Terraform and configure the Snowflake provider
2. Write a `snowflake_role` + `snowflake_table_grant` resource for the analyst role
3. Run `terraform plan` — review the diff
4. Run `terraform apply` — verify the role exists in Snowflake
5. Manually add an extra grant in Snowflake console, then run `terraform plan` again — observe drift detected
6. Run `terraform apply` to reconcile back to declared state

### Part 3: Data Catalog
1. Create data dictionary
2. Tag sensitive columns (mark email/SSN as PII in Terraform via column comments or policy tags)
3. Document data lineage
4. Generate data profile report

### Part 4: Compliance
1. Implement masking policies via Terraform (`snowflake_masking_policy` resource)
2. Create audit logging (`enable_user_activity_logging` parameter)
3. Design right-to-deletion workflow
4. Document in compliance matrix

*See Part 2 of course for complete lab walkthrough*

*Last Updated: March 2026*
